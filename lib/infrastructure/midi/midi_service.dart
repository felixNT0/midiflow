import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_midi_command/flutter_midi_command.dart';
import 'package:flutter_midi_command/flutter_midi_command_messages.dart';
import 'package:flutter_midi_command_ble/flutter_midi_command_ble.dart';

import '../logging/app_logger.dart';
import 'midi_device_model.dart';
import 'midi_message_model.dart';

/// Errors surfaced by the MIDI service.
class MidiServiceException implements Exception {
  MidiServiceException(this.message, {this.cause});

  final String message;
  final Object? cause;

  @override
  String toString() => 'MidiServiceException: $message';
}

/// MIDI engine status reported to the application layer.
enum MidiEngineStatus { uninitialized, initializing, ready, error }

/// Platform-facing MIDI service.
///
/// Wraps `flutter_midi_command` (with the optional
/// `flutter_midi_command_ble` transport) behind a small, widget-free API.
/// All plugin objects stay inside this class; the application layer only
/// sees [MidiDeviceInfo] and [MidiIncomingMessage].
class MidiService {
  MidiService({bool enableBle = true, MidiCommand? command})
    : _midi =
          command ??
          MidiCommand(
            bleTransport: enableBle ? UniversalBleMidiTransport() : null,
          ),
      _bleEnabled = enableBle;

  final MidiCommand _midi;
  final bool _bleEnabled;

  final Map<String, MidiDevice> _devicesById = {};
  final Map<String, StreamSubscription<MidiConnectionState>> _connectionSubs =
      {};

  final _devicesChangedCtrl =
      StreamController<List<MidiDeviceInfo>>.broadcast();
  final _messagesCtrl = StreamController<MidiIncomingMessage>.broadcast();

  StreamSubscription<MidiDataReceivedEvent>? _rxSub;
  StreamSubscription<MidiSetupChange>? _setupSub;

  MidiEngineStatus _status = MidiEngineStatus.uninitialized;
  String? _lastError;
  bool _disposed = false;

  MidiEngineStatus get status => _status;
  String? get lastError => _lastError;
  bool get isBleEnabled => _bleEnabled;
  BluetoothState get bluetoothState => _midi.bluetoothState;

  /// Emits the latest device snapshot whenever the MIDI topology changes.
  Stream<List<MidiDeviceInfo>> get onDevicesChanged =>
      _devicesChangedCtrl.stream;

  /// Emits every parsed incoming (and locally sent) MIDI message.
  Stream<MidiIncomingMessage> get onMessage => _messagesCtrl.stream;

  /// Initializes transports, subscriptions and BLE scanning.
  ///
  /// Safe to call once; subsequent calls are no-ops while ready.
  Future<void> initialize() async {
    if (_disposed) {
      throw MidiServiceException('MidiService has been disposed.');
    }
    if (_status == MidiEngineStatus.ready ||
        _status == MidiEngineStatus.initializing) {
      return;
    }
    _status = MidiEngineStatus.initializing;
    _lastError = null;
    appLogger.info('MIDI service initializing...');
    try {
      // Streams must be obtained after BLE transport configuration (done in
      // the constructor) and subscribed before scanning starts.
      _rxSub = _midi.onMidiDataReceived?.listen(_handleIncomingEvent);
      _setupSub = _midi.onMidiSetupChanged?.listen((_) {
        unawaited(refreshDevices());
      });

      if (_bleEnabled) {
        await _midi.startBluetooth();
        await _midi.waitUntilBluetoothIsInitialized();
        if (_midi.bluetoothState == BluetoothState.poweredOn) {
          await _midi.startScanningForBluetoothDevices();
          appLogger.info('BLE scanning started');
        } else {
          appLogger.warning(
            'BLE MIDI: Bluetooth state is ${_midi.bluetoothState}; '
            'BLE scan not started.',
          );
        }
      }

      await refreshDevices();
      _status = MidiEngineStatus.ready;
      appLogger.info('MIDI service ready');
    } catch (e, stackTrace) {
      _status = MidiEngineStatus.error;
      _lastError = e.toString();
      appLogger.error('MIDI service initialization failed', e, stackTrace);
      rethrow;
    }
  }

  /// Re-enumerates devices and notifies listeners.
  Future<List<MidiDeviceInfo>> refreshDevices() async {
    _devicesById.clear();
    for (final sub in _connectionSubs.values) {
      await sub.cancel();
    }
    _connectionSubs.clear();

    final devices = await _midi.devices ?? const <MidiDevice>[];
    final infos = [for (final d in devices) MidiDeviceInfo.fromPlugin(d)];
    for (final d in devices) {
      _devicesById[d.id] = d;
      _connectionSubs[d.id] = d.onConnectionStateChanged.listen((state) {
        unawaited(refreshDevices());
      });
    }
    if (!_disposed && !_devicesChangedCtrl.isClosed) {
      _devicesChangedCtrl.add(List.unmodifiable(infos));
    }
    return infos;
  }

  /// Connects to [device]. Completes only when a MIDI path is ready.
  ///
  /// Disconnects all other devices first to prevent interference.
  /// Throws [MidiConnectionException] subclasses on failure.
  Future<void> connect(MidiDeviceInfo device) async {
    final target = _requirePluginDevice(device.id);

    // Disconnect all other connected devices to prevent interference
    for (final otherDevice in _devicesById.values) {
      if (otherDevice.id != device.id && otherDevice.connected) {
        try {
          _midi.disconnectDevice(otherDevice);
          appLogger.info('Disconnected ${otherDevice.name} to connect ${device.name}');
        } catch (e) {
          // Ignore disconnect errors for other devices
          appLogger.warning('Failed to disconnect ${otherDevice.name}: $e');
        }
      }
    }

    try {
      await _midi.connectToDevice(target);
      // Refresh so the snapshot reflects the connected state and any ports
      // the platform exposed after connecting.
      await refreshDevices();
      appLogger.info('Connected to ${device.name}');
    } on MidiConnectionException {
      appLogger.error('Failed to connect to ${device.name}');
      rethrow;
    } catch (e, stackTrace) {
      appLogger.error('Failed to connect to ${device.name}', e, stackTrace);
      throw MidiServiceException(
        'Failed to connect to ${device.name}.',
        cause: e,
      );
    }
  }

  /// Disconnects [device]. Fire-and-forget at the plugin level; the device
  /// connection-state stream drives the UI update.
  void disconnect(MidiDeviceInfo device) {
    final target = _devicesById[device.id];
    if (target == null) {
      throw MidiServiceException('Unknown device: ${device.id}');
    }
    _midi.disconnectDevice(target);
  }

  /// Disconnects all connected devices.
  Future<void> disconnectAll() async {
    for (final device in _devicesById.values) {
      if (device.connected) {
        try {
          _midi.disconnectDevice(device);
          appLogger.info('Disconnected ${device.name}');
        } catch (e, stackTrace) {
          appLogger.warning('Failed to disconnect ${device.name}: $e', e, stackTrace);
        }
      }
    }
    await refreshDevices();
  }

  /// Sends a MIDI Control Change message to [device].
  ///
  /// [channel] is user-facing 1-16; [controller] and [value] are 0-127.
  /// Awaits actual transport delivery where the backend supports it (BLE)
  /// and surfaces write failures instead of silently succeeding.
  Future<void> sendControlChange({
    required MidiDeviceInfo device,
    required int channel,
    required int controller,
    required int value,
  }) async {
    final bytes = buildControlChangeBytes(
      channel: channel,
      controller: controller,
      value: value,
    );
    _requirePluginDevice(device.id);
    try {
      await _midi.sendDataAwaitingDelivery(bytes, deviceId: device.id);
      appLogger.debug(
        'Sent CC ch=$channel cc=$controller val=$value to ${device.name}',
      );
    } catch (e, stackTrace) {
      appLogger.error(
        'Failed to send CC$controller=$value on channel $channel to ${device.name}',
        e,
        stackTrace,
      );
      throw MidiServiceException(
        'Failed to send CC$controller=$value on channel $channel.',
        cause: e,
      );
    }
    _emitOutgoing(bytes, device);
  }

  /// Sends a MIDI Note On message to [device].
  ///
  /// [channel] is user-facing 1-16; [note] and [velocity] are 0-127
  /// (velocity 1-127; 0 behaves as note off on most devices).
  Future<void> sendNoteOn({
    required MidiDeviceInfo device,
    required int channel,
    required int note,
    required int velocity,
  }) =>
      _sendNote(device: device, channel: channel, note: note, velocity: velocity, on: true);

  /// Sends a MIDI Note Off message to [device].
  Future<void> sendNoteOff({
    required MidiDeviceInfo device,
    required int channel,
    required int note,
    int velocity = 0,
  }) =>
      _sendNote(device: device, channel: channel, note: note, velocity: velocity, on: false);

  Future<void> _sendNote({
    required MidiDeviceInfo device,
    required int channel,
    required int note,
    required int velocity,
    required bool on,
  }) async {
    if (channel < midiMinChannel ||
        channel > midiMaxChannel ||
        note < midiMinValue ||
        note > midiMaxValue ||
        velocity < midiMinValue ||
        velocity > midiMaxValue) {
      throw MidiServiceException('Invalid MIDI note values.');
    }
    final protocolChannel = channel - 1;
    final status = (on ? 0x90 : 0x80) + protocolChannel;
    final data = Uint8List.fromList([status, note, velocity]);
    _requirePluginDevice(device.id);
    try {
      await _midi.sendDataAwaitingDelivery(data, deviceId: device.id);
    } catch (e) {
      throw MidiServiceException(
        'Failed to send note $note on channel $channel.',
        cause: e,
      );
    }
    _emitOutgoing(data, device);
  }

  /// Sends pre-encoded MIDI bytes to [device]. Used by the bridge for
  /// message types beyond CC.
  Future<void> sendRaw(Uint8List data, {required MidiDeviceInfo device}) async {
    _requirePluginDevice(device.id);
    try {
      await _midi.sendDataAwaitingDelivery(data, deviceId: device.id);
    } catch (e) {
      throw MidiServiceException('Failed to send MIDI data.', cause: e);
    }
  }

  /// Creates and connects a virtual MIDI source endpoint that other
  /// applications see as a real MIDI input (Apple platforms via the
  /// "own-virtual" device in `flutter_midi_command_darwin`).
  ///
  /// Used by the desktop bridge: messages sent to the returned device are
  /// published onto the virtual source, which DAWs like FL Studio can select.
  /// Returns the connected [MidiDeviceInfo] to send through.
  Future<MidiDeviceInfo> createBridgeEndpoint({
    String name = 'MIDIFlow Bridge',
  }) async {
    await _midi.addVirtualDevice(name: name);
    await refreshDevices();
    MidiDevice? target;
    for (final d in _devicesById.values) {
      if (d.name == name && d.type == MidiDeviceType.ownVirtual) {
        target = d;
        break;
      }
    }
    if (target == null) {
      throw MidiServiceException(
        'Virtual endpoint "$name" was not enumerated after creation.',
      );
    }
    await _midi.connectToDevice(target);
    await refreshDevices();
    return MidiDeviceInfo.fromPlugin(target);
  }

  /// Removes a virtual endpoint previously created by [createBridgeEndpoint].
  Future<void> removeBridgeEndpoint({String name = 'MIDIFlow Bridge'}) async {
    await _midi.removeVirtualDevice(name: name);
    await refreshDevices();
  }

  /// Tears down subscriptions and transport resources.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _rxSub?.cancel();
    await _setupSub?.cancel();
    for (final sub in _connectionSubs.values) {
      await sub.cancel();
    }
    _connectionSubs.clear();
    if (_bleEnabled) {
      _midi.stopScanningForBluetoothDevices();
    }
    _midi.teardown();
    await _devicesChangedCtrl.close();
    await _messagesCtrl.close();
  }

  MidiDevice _requirePluginDevice(String id) {
    final device = _devicesById[id];
    if (device == null) {
      throw MidiServiceException('Device is not available: $id');
    }
    return device;
  }

  void _handleIncomingEvent(MidiDataReceivedEvent event) {
    _messagesCtrl.add(_describePluginMessage(event));
  }

  void _emitOutgoing(Uint8List bytes, MidiDeviceInfo device) {
    _messagesCtrl.add(
      MidiIncomingMessage(
        timestamp: DateTime.now(),
        direction: MidiMessageDirection.outgoing,
        sourceDevice: device.name,
        kind: MidiMessageKind.controlChange,
        channel: null,
        rawBytes: _hex(bytes),
      ),
    );
  }

  MidiIncomingMessage _describePluginMessage(MidiDataReceivedEvent event) {
    final message = event.message;
    final deviceName = event.device.name;
    final channel = _channelOf(message);

    MidiMessageKind kind;
    int? controller;
    int? note;
    int? value;
    String? detail;

    if (message is CCMessage) {
      kind = MidiMessageKind.controlChange;
      controller = message.controller;
      value = message.value;
    } else if (message is NoteOnMessage) {
      kind = MidiMessageKind.noteOn;
      note = message.note;
      value = message.velocity;
    } else if (message is NoteOffMessage) {
      kind = MidiMessageKind.noteOff;
      note = message.note;
      value = message.velocity;
    } else if (message is PitchBendMessage) {
      kind = MidiMessageKind.pitchBend;
      detail = 'bend ${message.bend}';
    } else if (message is PCMessage) {
      kind = MidiMessageKind.programChange;
      value = message.program;
    } else if (message is SysExMessage) {
      kind = MidiMessageKind.sysex;
      detail = '${message.data.length} bytes';
    } else {
      kind = MidiMessageKind.other;
      detail = message.runtimeType.toString();
    }

    return MidiIncomingMessage(
      timestamp: DateTime.fromMillisecondsSinceEpoch(event.timestamp),
      direction: MidiMessageDirection.incoming,
      sourceDevice: deviceName,
      kind: kind,
      channel: channel,
      controller: controller,
      note: note,
      value: value,
      rawBytes: _hex(message.generateData()),
      detail: detail,
    );
  }

  /// Converts a plugin message's zero-based channel to user-facing 1-16.
  int? _channelOf(MidiMessage message) {
    final int? channel;
    if (message is CCMessage) {
      channel = message.channel;
    } else if (message is NoteOnMessage) {
      channel = message.channel;
    } else if (message is NoteOffMessage) {
      channel = message.channel;
    } else if (message is PitchBendMessage) {
      channel = message.channel;
    } else if (message is PCMessage) {
      channel = message.channel;
    } else {
      channel = null;
    }
    return channel == null ? null : channel + 1;
  }

  static String _hex(Uint8List bytes) {
    return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ');
  }
}
