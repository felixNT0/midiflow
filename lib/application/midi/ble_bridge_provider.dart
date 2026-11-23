import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/midi/midi_device_model.dart';
import '../../infrastructure/midi/network/ble_midi_parser.dart';
import '../../infrastructure/midi/network/ble_midi_peripheral.dart';
import 'midi_provider.dart';

/// BLE MIDI peripheral state for desktop bridge.
class BleBridgeState {
  const BleBridgeState({
    this.running = false,
    this.starting = false,
    this.error,
    this.connectedClients = 0,
  });

  final bool running;
  final bool starting;
  final String? error;
  final int connectedClients;

  BleBridgeState copyWith({
    bool? running,
    bool? starting,
    String? error,
    int? connectedClients,
    bool clearError = false,
  }) {
    return BleBridgeState(
      running: running ?? this.running,
      starting: starting ?? this.starting,
      error: clearError ? null : (error ?? this.error),
      connectedClients: connectedClients ?? this.connectedClients,
    );
  }
}

/// BLE MIDI peripheral controller for desktop bridge.
/// Allows phones/tablets to connect via Bluetooth LE instead of Wi-Fi.
class BleBridgeController extends Notifier<BleBridgeState> {
  BleMidiPeripheral? _peripheral;
  StreamSubscription<List<int>>? _midiDataSub;
  StreamSubscription<String>? _connectionSub;

  @override
  BleBridgeState build() {
    ref.onDispose(_dispose);
    return const BleBridgeState();
  }

  Future<void> start() async {
    if (state.running || state.starting) return;
    state = state.copyWith(starting: true, clearError: true);

    try {
      _peripheral = BleMidiPeripheral();

      // Initialize BLE peripheral
      await _peripheral!.initialize(deviceName: 'MIDIFlow Bridge');

      // Listen for MIDI data from BLE clients
      _midiDataSub = _peripheral!.onMidiData.listen(_handleMidiData);

      // Listen for connection state changes
      _connectionSub = _peripheral!.onConnectionState.listen(_handleConnectionState);

      // Start advertising
      await _peripheral!.startAdvertising();

      state = state.copyWith(running: true, starting: false);
    } catch (e) {
      state = state.copyWith(
        starting: false,
        error: 'Failed to start BLE bridge: $e',
      );
      await _dispose();
    }
  }

  Future<void> stop() async {
    if (!state.running) return;
    await _dispose();
    state = const BleBridgeState();
  }

  void _handleMidiData(List<int> data) {
    // Parse BLE MIDI packet and convert to standard MIDI messages
    final packet = Uint8List.fromList(data);
    final messages = BleMidiParser.parsePacket(packet);

    // Send parsed messages to MIDI service
    for (final msg in messages) {
      _sendToMidiService(msg);
    }
  }

  void _handleConnectionState(String connectionState) {
    // Update connected clients count
    if (connectionState == 'connected') {
      state = state.copyWith(connectedClients: state.connectedClients + 1);
    } else if (connectionState == 'disconnected') {
      state = state.copyWith(
        connectedClients: (state.connectedClients - 1).clamp(0, 999),
      );
    }
  }

  void _sendToMidiService(MidiMessage message) {
    // Convert parsed MIDI message to standard MIDI and send to FL Studio
    // This integrates with the existing MIDI service
    final midiService = ref.read(midiServiceProvider);
    final device = _getSelectedDevice();

    if (device == null) return;

    if (message.kind == MidiMessageKind.controlChange &&
        message.controller != null &&
        message.value != null) {
      // Send CC message
      midiService.sendControlChange(
        device: device,
        channel: message.channel ?? 1,
        controller: message.controller!,
        value: message.value!,
      );
    }
  }

  MidiDeviceInfo? _getSelectedDevice() {
    // Get the currently selected MIDI device
    final midiState = ref.read(midiControllerProvider);
    return midiState.selectedDevice;
  }

  /// Sends MIDI data to connected BLE clients.
  Future<void> sendMidiData(List<int> data) async {
    if (!state.running || _peripheral == null) return;
    await _peripheral!.sendMidiData(data);
  }

  Future<void> _dispose() async {
    await _midiDataSub?.cancel();
    await _connectionSub?.cancel();
    await _peripheral?.dispose();
    _peripheral = null;
    _midiDataSub = null;
    _connectionSub = null;
  }
}

final bleBridgeProvider = NotifierProvider<BleBridgeController, BleBridgeState>(
  BleBridgeController.new,
);
