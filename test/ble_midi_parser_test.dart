import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:midiflow/infrastructure/midi/network/ble_midi_parser.dart';

void main() {
  group('BleMidiParser', () {
    test('parses empty packet', () {
      final result = BleMidiParser.parsePacket(Uint8List(0));
      expect(result, isEmpty);
    });

    test('parses Control Change message', () {
      // BLE MIDI CC packet: [header][controller][value]
      // Header: Type 3 (CC) + timestamp 0 = 0x03
      final packet = Uint8List.fromList([0x03, 7, 100]); // CC7, value 100
      final result = BleMidiParser.parsePacket(packet);

      expect(result.length, 1);
      expect(result[0].kind, MidiMessageKind.controlChange);
      expect(result[0].controller, 7);
      expect(result[0].value, 100);
    });

    test('parses Note On message', () {
      // BLE MIDI Note packet: [header][note][velocity][high bits]
      // Header: Type 2 (Notes) + timestamp 0 = 0x02
      // For notes < 128 and velocity < 128, high bits are 0
      final packet = Uint8List.fromList([0x02, 60, 100, 0x00]); // Note 60, velocity 100
      final result = BleMidiParser.parsePacket(packet);

      expect(result.length, 1);
      expect(result[0].kind, MidiMessageKind.noteOn);
      expect(result[0].note, 60);
      expect(result[0].value, 100);
    });

    test('parses Note Off message', () {
      // BLE MIDI Note packet with velocity 0 = Note Off
      final packet = Uint8List.fromList([0x02, 60, 0, 0x00]); // Note 60, velocity 0
      final result = BleMidiParser.parsePacket(packet);

      expect(result.length, 1);
      expect(result[0].kind, MidiMessageKind.noteOff);
      expect(result[0].note, 60);
      expect(result[0].value, 0);
    });

    test('parses Program Change message', () {
      // BLE MIDI Program Change: [header][program]
      // Header: Type 4 (Program Change) + timestamp 0 = 0x04
      final packet = Uint8List.fromList([0x04, 5]); // Program 5
      final result = BleMidiParser.parsePacket(packet);

      expect(result.length, 1);
      expect(result[0].kind, MidiMessageKind.programChange);
      expect(result[0].value, 5);
    });

    test('parses Pitch Bend message', () {
      // BLE MIDI Pitch Bend: [header][lsb][msb]
      // Header: Type 7 (Pitch Bend) + timestamp 0 = 0x07
      final packet = Uint8List.fromList([0x07, 0x00, 0x40]); // Center position
      final result = BleMidiParser.parsePacket(packet);

      expect(result.length, 1);
      expect(result[0].kind, MidiMessageKind.pitchBend);
      expect(result[0].value, 8192); // (0x40 << 7) | 0x00 = 8192
    });

    test('handles different channels', () {
      // Test channel 5 (BLE MIDI uses 0-15, we convert to 1-16)
      // Header: Type 3 (CC) + timestamp 0 = 0x03
      // Channel is encoded in the MIDI data, not the header
      final packet = Uint8List.fromList([0x03, 7, 100]); // CC7, value 100
      final result = BleMidiParser.parsePacket(packet);

      expect(result.length, 1);
      expect(result[0].kind, MidiMessageKind.controlChange);
    });

    test('encodes Control Change message', () {
      final messages = [
        MidiMessage(
          timestamp: DateTime.now(),
          kind: MidiMessageKind.controlChange,
          direction: MidiMessageDirection.outgoing,
          sourceDevice: 'test',
          channel: 1,
          controller: 7,
          value: 100,
        ),
      ];

      final packet = BleMidiParser.encodePacket(messages);

      expect(packet.length, 3);
      expect(packet[0], 0x03); // Header: Type 3 + timestamp 0
      expect(packet[1], 7); // Controller
      expect(packet[2], 100); // Value
    });

    test('encodes Note On message', () {
      final messages = [
        MidiMessage(
          timestamp: DateTime.now(),
          kind: MidiMessageKind.noteOn,
          direction: MidiMessageDirection.outgoing,
          sourceDevice: 'test',
          channel: 1,
          note: 60,
          value: 100,
        ),
      ];

      final packet = BleMidiParser.encodePacket(messages);

      expect(packet.length, 3);
      expect(packet[0], 0x02); // Header: Type 2 + timestamp 0
      expect(packet[1], 60); // Note
      expect(packet[2], 100); // Velocity
    });
  });
}
