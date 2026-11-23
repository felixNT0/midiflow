import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

/// BLE MIDI peripheral service that allows phones/tablets to connect
/// to the desktop app via Bluetooth LE and send/receive MIDI data.
///
/// Implements the BLE MIDI specification:
/// - Service UUID: 03B80E5A-EDE8-4B33-A751-6CE34EC4C700
/// - MIDI Characteristic: 7772E5DB-3868-4112-A1A9-F2669D106BF3 (write)
/// - MIDI Input Characteristic: 7E4D0001-1CC1-11E3-8CF5-0002A5D5C51B (notify)
class BleMidiPeripheral {
  static const String _serviceUuid = '03B80E5A-EDE8-4B33-A751-6CE34EC4C700';
  static const String _midiCharacteristicUuid =
      '7772E5DB-3868-4112-A1A9-F2669D106BF3';
  static const String _midiInputCharacteristicUuid =
      '7E4D0001-1CC1-11E3-8CF5-0002A5D5C51B';

  final StreamController<List<int>> _midiDataCtrl =
      StreamController<List<int>>.broadcast();
  final StreamController<String> _connectionStateCtrl =
      StreamController<String>.broadcast();

  Stream<List<int>> get onMidiData => _midiDataCtrl.stream;
  Stream<String> get onConnectionState => _connectionStateCtrl.stream;

  bool _isAdvertising = false;
  bool _isInitialized = false;
  String? _deviceName;

  bool get isAdvertising => _isAdvertising;
  bool get isInitialized => _isInitialized;

  /// Initializes the BLE peripheral and adds the MIDI service.
  Future<void> initialize({String? deviceName}) async {
    if (_isInitialized) return;

    _deviceName = deviceName ?? 'MIDIFlow Bridge';

    try {
      // Check if peripheral is supported
      final availability = await UniversalBlePeripheral.getAvailabilityState();
      if (availability != PeripheralReadinessState.ready) {
        throw Exception('BLE peripheral not ready: $availability');
      }

      // Create MIDI service
      final midiService = BlePeripheralService(
        uuid: _serviceUuid,
        characteristics: [
          BlePeripheralCharacteristic(
            uuid: _midiCharacteristicUuid,
            properties: [
              CharacteristicProperty.write,
              CharacteristicProperty.writeWithoutResponse,
            ],
            permissions: [PeripheralAttributePermission.writeable],
          ),
          BlePeripheralCharacteristic(
            uuid: _midiInputCharacteristicUuid,
            properties: [CharacteristicProperty.notify],
            permissions: [PeripheralAttributePermission.readable],
          ),
        ],
      );

      // Add the service
      await UniversalBlePeripheral.addService(midiService);

      // Set up write handler for incoming MIDI data
      UniversalBlePeripheral.setWriteRequestHandlers(
        (deviceId, characteristicId, offset, value) {
          if (characteristicId == _midiCharacteristicUuid && value != null) {
            _midiDataCtrl.add(value.toList());
          }
          return null; // Accept the write
        },
      );

      // Set up connection state handler
      UniversalBlePeripheral.connectionStateStream.listen((event) {
        _connectionStateCtrl.add(event.toString());
      });

      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize BLE peripheral: $e');
    }
  }

  /// Starts advertising as a BLE MIDI device.
  Future<void> startAdvertising() async {
    if (!_isInitialized) {
      throw Exception('BLE peripheral not initialized');
    }
    if (_isAdvertising) return;

    try {
      await UniversalBlePeripheral.startAdvertising(
        services: [_serviceUuid],
        localName: _deviceName,
      );
      _isAdvertising = true;
      _connectionStateCtrl.add('advertising');
    } catch (e) {
      throw Exception('Failed to start advertising: $e');
    }
  }

  /// Stops advertising.
  Future<void> stopAdvertising() async {
    if (!_isAdvertising) return;

    try {
      await UniversalBlePeripheral.stopAdvertising();
      _isAdvertising = false;
      _connectionStateCtrl.add('stopped');
    } catch (e) {
      throw Exception('Failed to stop advertising: $e');
    }
  }

  /// Sends MIDI data to connected clients.
  Future<void> sendMidiData(List<int> data) async {
    if (!_isInitialized || !_isAdvertising) return;

    try {
      await UniversalBlePeripheral.updateCharacteristicValue(
        characteristicId: _midiInputCharacteristicUuid,
        value: Uint8List.fromList(data),
      );
    } catch (e) {
      // Ignore send errors - client may have disconnected
    }
  }

  /// Disconnects all clients.
  Future<void> disconnectAll() async {
    // This would need to be implemented based on client tracking
    // For now, just stop advertising
    await stopAdvertising();
  }

  /// Disposes of resources.
  Future<void> dispose() async {
    await stopAdvertising();
    await _midiDataCtrl.close();
    await _connectionStateCtrl.close();
  }
}
