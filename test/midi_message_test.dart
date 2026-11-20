import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:midiflow/infrastructure/midi/midi_message_model.dart';

void main() {
  group('buildControlChangeBytes', () {
    test('builds spec example: channel 1, CC 7, value 100', () {
      final bytes = buildControlChangeBytes(
        channel: 1,
        controller: 7,
        value: 100,
      );
      expect(bytes, equals(Uint8List.fromList([0xB0, 7, 100])));
    });

    test('converts user channel 16 to protocol channel 15', () {
      final bytes = buildControlChangeBytes(
        channel: 16,
        controller: 0,
        value: 127,
      );
      expect(bytes[0], equals(0xB0 + 15));
      expect(bytes[1], equals(0));
      expect(bytes[2], equals(127));
    });

    test('produces exactly 3 bytes', () {
      expect(
        buildControlChangeBytes(channel: 5, controller: 64, value: 0).length,
        equals(3),
      );
    });

    test('rejects channel 0', () {
      expect(
        () => buildControlChangeBytes(channel: 0, controller: 1, value: 1),
        throwsArgumentError,
      );
    });

    test('rejects channel 17', () {
      expect(
        () => buildControlChangeBytes(channel: 17, controller: 1, value: 1),
        throwsArgumentError,
      );
    });

    test('rejects controller above 127', () {
      expect(
        () => buildControlChangeBytes(channel: 1, controller: 128, value: 1),
        throwsArgumentError,
      );
    });

    test('rejects negative controller', () {
      expect(
        () => buildControlChangeBytes(channel: 1, controller: -1, value: 1),
        throwsArgumentError,
      );
    });

    test('rejects value above 127', () {
      expect(
        () => buildControlChangeBytes(channel: 1, controller: 1, value: 128),
        throwsArgumentError,
      );
    });

    test('rejects negative value', () {
      expect(
        () => buildControlChangeBytes(channel: 1, controller: 1, value: -1),
        throwsArgumentError,
      );
    });
  });

  group('validateMidiChannel', () {
    test('returns zero-based protocol channel', () {
      expect(validateMidiChannel(1), equals(0));
      expect(validateMidiChannel(16), equals(15));
    });
  });

  group('MidiIncomingMessage.describe', () {
    test('formats a control change entry', () {
      final m = MidiIncomingMessage(
        timestamp: DateTime(2026, 1, 1, 12),
        direction: MidiMessageDirection.incoming,
        sourceDevice: 'Test Device',
        kind: MidiMessageKind.controlChange,
        channel: 1,
        controller: 7,
        value: 100,
        rawBytes: 'b0 07 64',
      );
      final text = m.describe();
      expect(text, contains('IN'));
      expect(text, contains('Test Device'));
      expect(text, contains('controlChange'));
      expect(text, contains('ch1'));
      expect(text, contains('cc7'));
      expect(text, contains('=100'));
    });
  });
}
