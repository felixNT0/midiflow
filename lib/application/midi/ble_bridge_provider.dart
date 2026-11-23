import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../infrastructure/midi/network/ble_midi_peripheral.dart';

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
    // Convert BLE MIDI data to standard MIDI messages
    // BLE MIDI uses a different format with timestamp headers
    // For now, we'll pass raw data to the MIDI service
    // This needs to be implemented based on BLE MIDI spec
    _sendToMidiService(data);
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

  void _sendToMidiService(List<int> data) {
    // This would need to integrate with the MIDI service
    // to send the received MIDI data to FL Studio
    // For now, we'll just log it
    print('BLE MIDI data received: ${data.length} bytes');
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
