import 'package:flutter_test/flutter_test.dart';
import 'package:midiflow/domain/midi/midi_control.dart';

void main() {
  const mapping = ControlMapping(channel: 1, controller: 7);

  group('normalizedToMidi', () {
    test('maps 0.0 to min and 1.0 to max', () {
      expect(normalizedToMidi(0.0, mapping), equals(0));
      expect(normalizedToMidi(1.0, mapping), equals(127));
    });

    test('scales linearly', () {
      // 0.5 * 127 = 63.5 -> rounds to 64 (dart round: half away from zero? .5 -> 64)
      expect(normalizedToMidi(0.5, mapping), equals(64));
    });

    test('honours custom min/max range', () {
      const m = ControlMapping(minValue: 10, maxValue: 20);
      expect(normalizedToMidi(0.0, m), equals(10));
      expect(normalizedToMidi(1.0, m), equals(20));
      expect(normalizedToMidi(0.5, m), equals(15));
    });

    test('inversion swaps endpoints', () {
      const m = ControlMapping(inverted: true);
      expect(normalizedToMidi(0.0, m), equals(127));
      expect(normalizedToMidi(1.0, m), equals(0));
    });

    test('clamps out-of-range normalized input', () {
      expect(normalizedToMidi(-0.5, mapping), equals(0));
      expect(normalizedToMidi(1.5, mapping), equals(127));
    });
  });

  group('midiToNormalized', () {
    test('round-trips with normalizedToMidi', () {
      for (final v in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final midi = normalizedToMidi(v, mapping);
        expect(midiToNormalized(midi, mapping), closeTo(v, 0.01));
      }
    });

    test('inverted mapping round-trips', () {
      const m = ControlMapping(inverted: true);
      final midi = normalizedToMidi(0.3, m);
      expect(midiToNormalized(midi, m), closeTo(0.3, 0.01));
    });
  });

  group('button values', () {
    test('on = max, off = min', () {
      expect(buttonOnValue(mapping), equals(127));
      expect(buttonOffValue(mapping), equals(0));
    });

    test('custom range respected', () {
      const m = ControlMapping(minValue: 64, maxValue: 127);
      expect(buttonOnValue(m), equals(127));
      expect(buttonOffValue(m), equals(64));
    });
  });

  group('ControlMapping.validate', () {
    test('accepts valid mapping', () {
      const ControlMapping(channel: 16, controller: 127).validate();
    });

    test('rejects channel 0', () {
      expect(
        () => const ControlMapping(channel: 0).validate(),
        throwsArgumentError,
      );
    });

    test('rejects min > max', () {
      expect(
        () => const ControlMapping(minValue: 100, maxValue: 50).validate(),
        throwsArgumentError,
      );
    });
  });

  group('MidiControl', () {
    test('currentMidiValue reflects normalizedValue', () {
      final c = MidiControl(
        id: 'a',
        label: 'A',
        type: MidiControlType.fader,
        mapping: mapping,
        normalizedValue: 1.0,
      );
      expect(c.currentMidiValue, equals(127));
    });

    test('normalizedValue is clamped on construction', () {
      final c = MidiControl(
        id: 'a',
        label: 'A',
        type: MidiControlType.fader,
        normalizedValue: 2.0,
      );
      expect(c.normalizedValue, equals(1.0));
    });
  });
}
