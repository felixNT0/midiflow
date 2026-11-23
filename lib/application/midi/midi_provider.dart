import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/midi/midi_device_model.dart';
import '../../infrastructure/midi/midi_message_model.dart';
import '../../infrastructure/midi/midi_service.dart';

/// Application-lifetime MIDI service. Disposed with the provider container.
final midiServiceProvider = Provider<MidiService>((ref) {
  final service = MidiService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

/// Maximum number of entries kept in the incoming message log.
const int midiLogMaxEntries = 200;

/// Connection mode for MIDI devices.
enum ConnectionMode { wifi, ble, usb, auto }

/// Immutable UI-facing MIDI state.
class MidiState {
  const MidiState({
    this.status = MidiEngineStatus.uninitialized,
    this.devices = const [],
    this.selectedDeviceId,
    this.connectionMode = ConnectionMode.auto,
    this.channel = 1,
    this.controller = 7,
    this.ccValue = 100,
    this.messages = const [],
    this.error,
    this.busy = false,
  });

  final MidiEngineStatus status;
  final List<MidiDeviceInfo> devices;
  final String? selectedDeviceId;
  final ConnectionMode connectionMode;
  final int channel;
  final int controller;
  final int ccValue;
  final List<MidiIncomingMessage> messages;
  final String? error;
  final bool busy;

  /// Devices filtered by connection mode.
  List<MidiDeviceInfo> get filteredDevices {
    if (connectionMode == ConnectionMode.auto) return devices;
    return devices.where((d) {
      switch (connectionMode) {
        case ConnectionMode.wifi:
          return d.kind == MidiDeviceKind.network;
        case ConnectionMode.ble:
          return d.kind == MidiDeviceKind.ble;
        case ConnectionMode.usb:
          return d.kind == MidiDeviceKind.usb;
        case ConnectionMode.auto:
          return true;
      }
    }).toList();
  }

  MidiDeviceInfo? get selectedDevice {
    for (final d in devices) {
      if (d.id == selectedDeviceId) return d;
    }
    return null;
  }

  bool get isConnected => selectedDevice?.isConnected ?? false;

  MidiState copyWith({
    MidiEngineStatus? status,
    List<MidiDeviceInfo>? devices,
    String? selectedDeviceId,
    bool clearSelectedDevice = false,
    ConnectionMode? connectionMode,
    int? channel,
    int? controller,
    int? ccValue,
    List<MidiIncomingMessage>? messages,
    String? error,
    bool clearError = false,
    bool? busy,
  }) {
    return MidiState(
      status: status ?? this.status,
      devices: devices ?? this.devices,
      selectedDeviceId: clearSelectedDevice
          ? null
          : (selectedDeviceId ?? this.selectedDeviceId),
      connectionMode: connectionMode ?? this.connectionMode,
      channel: channel ?? this.channel,
      controller: controller ?? this.controller,
      ccValue: ccValue ?? this.ccValue,
      messages: messages ?? this.messages,
      error: clearError ? null : (error ?? this.error),
      busy: busy ?? this.busy,
    );
  }
}

/// Drives MIDI discovery, connection and CC sending for the UI.
class MidiController extends Notifier<MidiState> {
  late final MidiService _service;
  StreamSubscription<List<MidiDeviceInfo>>? _devicesSub;
  StreamSubscription<MidiIncomingMessage>? _messagesSub;
  Timer? _reconnectTimer;
  String? _lastConnectedDeviceId;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _reconnectDelay = Duration(seconds: 2);

  /// Coalesces continuous CC streams (faders/knobs/XY drags) to at most one
  /// send per key per [_ccFlushInterval]; the latest value always wins and is
  /// flushed, so the final gesture value is never dropped.
  static const Duration _ccFlushInterval = Duration(milliseconds: 30);
  final Map<String, _PendingCc> _pendingCc = {};
  Timer? _ccFlushTimer;
  DateTime _lastCcFlush = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  MidiState build() {
    _service = ref.watch(midiServiceProvider);
    ref.onDispose(_dispose);
    // Deferred: state is not readable until build() returns.
    scheduleMicrotask(_initialize);
    return const MidiState();
  }

  Future<void> _initialize() async {
    state = state.copyWith(status: MidiEngineStatus.initializing);
    try {
      await _service.initialize();
      _devicesSub = _service.onDevicesChanged.listen((devices) {
        final previousSelectedId = state.selectedDeviceId;
        state = state.copyWith(
          status: _service.status,
          devices: devices,
          error: _service.lastError,
          clearError: _service.lastError == null,
        );

        // Check if selected device disconnected and attempt reconnection
        _checkAndReconnect(devices, previousSelectedId);
      });
      _messagesSub = _service.onMessage.listen((message) {
        final log = [...state.messages, message];
        if (log.length > midiLogMaxEntries) {
          log.removeRange(0, log.length - midiLogMaxEntries);
        }
        state = state.copyWith(messages: log);
      });
      state = state.copyWith(
        status: _service.status,
        error: _service.lastError,
        clearError: _service.lastError == null,
      );
    } catch (e) {
      state = state.copyWith(
        status: MidiEngineStatus.error,
        error: e.toString(),
      );
    }
  }

  Future<void> _dispose() async {
    _ccFlushTimer?.cancel();
    _reconnectTimer?.cancel();
    await _devicesSub?.cancel();
    await _messagesSub?.cancel();
  }

  /// Checks if the selected device disconnected and attempts reconnection.
  void _checkAndReconnect(List<MidiDeviceInfo> devices, String? previousSelectedId) {
    if (previousSelectedId == null) return;

    final device = devices.firstWhere(
      (d) => d.id == previousSelectedId,
      orElse: () => MidiDeviceInfo(
        id: '',
        name: '',
        kind: MidiDeviceKind.unknown,
        inputPorts: const [],
        outputPorts: const [],
        connectionState: MidiDeviceConnectionState.disconnected,
      ),
    );

    // If device was connected and now disconnected, attempt reconnection
    if (device.id.isNotEmpty &&
        device.connectionState == MidiDeviceConnectionState.disconnected &&
        _reconnectAttempts < _maxReconnectAttempts) {
      _scheduleReconnect(device.id);
    }
  }

  /// Schedules a reconnection attempt.
  void _scheduleReconnect(String deviceId) {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;

    state = state.copyWith(
      error: 'Reconnecting... (attempt $_reconnectAttempts/$_maxReconnectAttempts)',
    );

    _reconnectTimer = Timer(_reconnectDelay, () async {
      final device = state.devices.firstWhere(
        (d) => d.id == deviceId,
        orElse: () => MidiDeviceInfo(
          id: '',
          name: '',
          kind: MidiDeviceKind.unknown,
          inputPorts: const [],
          outputPorts: const [],
          connectionState: MidiDeviceConnectionState.disconnected,
        ),
      );

      if (device.id.isNotEmpty &&
          device.connectionState == MidiDeviceConnectionState.disconnected) {
        try {
          await _service.connect(device);
          _reconnectAttempts = 0;
          state = state.copyWith(
            selectedDeviceId: deviceId,
            error: null,
            clearError: true,
          );
        } catch (e) {
          // Reconnection failed, will retry if attempts remain
          if (_reconnectAttempts >= _maxReconnectAttempts) {
            state = state.copyWith(
              error: 'Failed to reconnect after $_maxReconnectAttempts attempts',
              clearError: false,
            );
            _reconnectAttempts = 0;
          } else {
            _scheduleReconnect(deviceId);
          }
        }
      }
    });
  }

  Future<void> refreshDevices() async {
    state = state.copyWith(busy: true, clearError: true);
    try {
      final devices = await _service.refreshDevices();
      state = state.copyWith(devices: devices, busy: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), busy: false);
    }
  }

  void selectDevice(String? deviceId) {
    state = state.copyWith(
      selectedDeviceId: deviceId,
      clearSelectedDevice: deviceId == null,
      clearError: true,
    );
  }

  /// Sets the connection mode and disconnects incompatible devices.
  Future<void> setConnectionMode(ConnectionMode mode) async {
    if (mode == state.connectionMode) return;

    // Disconnect all devices when switching modes to prevent interference
    await _service.disconnectAll();

    state = state.copyWith(
      connectionMode: mode,
      clearSelectedDevice: true, // Clear selection when switching modes
      clearError: true,
    );
  }

  Future<void> connectSelected() async {
    final device = state.selectedDevice;
    if (device == null) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _service.connect(device);
      state = state.copyWith(busy: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), busy: false);
    }
  }

  Future<void> disconnectSelected() async {
    final device = state.selectedDevice;
    if (device == null) return;
    state = state.copyWith(busy: true, clearError: true);
    try {
      _service.disconnect(device);
      state = state.copyWith(busy: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), busy: false);
    }
  }

  Future<void> sendControlChange() async {
    final device = state.selectedDevice;
    if (device == null || !device.isConnected) {
      state = state.copyWith(
        error: 'Select a connected output device first.',
        clearError: false,
      );
      return;
    }
    state = state.copyWith(busy: true, clearError: true);
    try {
      await _service.sendControlChange(
        device: device,
        channel: state.channel,
        controller: state.controller,
        value: state.ccValue,
      );
      state = state.copyWith(busy: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), busy: false);
    }
  }

  /// Sends a Note On to the selected connected device.
  Future<void> sendNoteOn({
    required int channel,
    required int note,
    int velocity = 100,
  }) async {
    final device = state.selectedDevice;
    if (device == null || !device.isConnected) return;
    try {
      await _service.sendNoteOn(
        device: device,
        channel: channel,
        note: note,
        velocity: velocity,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), clearError: false);
    }
  }

  /// Sends a Note Off to the selected connected device.
  Future<void> sendNoteOff({required int channel, required int note}) async {
    final device = state.selectedDevice;
    if (device == null || !device.isConnected) return;
    try {
      await _service.sendNoteOff(device: device, channel: channel, note: note);
    } catch (e) {
      state = state.copyWith(error: e.toString(), clearError: false);
    }
  }

  /// Sends a raw CC to the selected connected device.
  ///
  /// Continuous gestures should prefer this throttled path: values are
  /// coalesced per (channel, controller) and the most recent value is always
  /// delivered.
  Future<void> sendCc({
    required int channel,
    required int controller,
    required int value,
  }) async {
    final device = state.selectedDevice;
    if (device == null || !device.isConnected) {
      state = state.copyWith(
        error: 'Select a connected output device first.',
        clearError: false,
      );
      return;
    }

    // Reset reconnect attempts on successful send
    if (_reconnectAttempts > 0) {
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();
    }

    if (channel < midiMinChannel ||
        channel > midiMaxChannel ||
        controller < midiMinValue ||
        controller > midiMaxValue ||
        value < midiMinValue ||
        value > midiMaxValue) {
      state = state.copyWith(error: 'Invalid MIDI values.', clearError: false);
      return;
    }

    final key = '$channel:$controller';
    final now = DateTime.now();
    final elapsed = now.difference(_lastCcFlush);
    if (elapsed >= _ccFlushInterval && _pendingCc.isEmpty) {
      _lastCcFlush = now;
      await _dispatchCc(device, channel, controller, value);
      return;
    }
    _pendingCc[key] = _PendingCc(
      channel: channel,
      controller: controller,
      value: value,
    );
    _ccFlushTimer ??= Timer(_ccFlushInterval, _flushPendingCc);
  }

  Future<void> _flushPendingCc() async {
    _ccFlushTimer = null;
    _lastCcFlush = DateTime.now();
    final pending = _pendingCc.values.toList();
    _pendingCc.clear();
    final device = state.selectedDevice;
    if (device == null || !device.isConnected) return;
    for (final cc in pending) {
      await _dispatchCc(device, cc.channel, cc.controller, cc.value);
    }
  }

  Future<void> _dispatchCc(
    MidiDeviceInfo device,
    int channel,
    int controller,
    int value,
  ) async {
    try {
      await _service.sendControlChange(
        device: device,
        channel: channel,
        controller: controller,
        value: value,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), clearError: false);
    }
  }

  void setChannel(int channel) {
    if (channel < midiMinChannel || channel > midiMaxChannel) return;
    state = state.copyWith(channel: channel);
  }

  void setController(int controller) {
    if (controller < midiMinValue || controller > midiMaxValue) return;
    state = state.copyWith(controller: controller);
  }

  void setCcValue(int value) {
    if (value < midiMinValue || value > midiMaxValue) return;
    state = state.copyWith(ccValue: value);
  }

  void clearMessageLog() {
    state = state.copyWith(messages: const []);
  }
}

final midiControllerProvider = NotifierProvider<MidiController, MidiState>(
  MidiController.new,
);

class _PendingCc {
  const _PendingCc({
    required this.channel,
    required this.controller,
    required this.value,
  });

  final int channel;
  final int controller;
  final int value;
}
