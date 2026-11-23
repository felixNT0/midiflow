import 'package:flutter_test/flutter_test.dart';
import 'package:midiflow/domain/midi/control_bank.dart';
import 'package:midiflow/domain/midi/midi_control.dart';

void main() {
  group('MidiControl', () {
    test('creates control with valid mapping', () {
      final control = MidiControl(
        id: 'test-1',
        label: 'Test Fader',
        type: MidiControlType.fader,
        mapping: const ControlMapping(channel: 1, controller: 7),
      );

      expect(control.id, 'test-1');
      expect(control.label, 'Test Fader');
      expect(control.type, MidiControlType.fader);
      expect(control.mapping.channel, 1);
      expect(control.mapping.controller, 7);
    });

    test('copyWith creates new instance with updated values', () {
      final control = MidiControl(
        id: 'test-1',
        label: 'Test',
        type: MidiControlType.fader,
        mapping: const ControlMapping(channel: 1, controller: 7),
      );

      final updated = control.copyWith(
        label: 'Updated',
        normalizedValue: 0.5,
      );

      expect(updated.label, 'Updated');
      expect(updated.normalizedValue, 0.5);
      expect(updated.id, 'test-1'); // ID should remain same
    });

    test('validates MIDI channel range', () {
      expect(() => const ControlMapping(channel: 0, controller: 7).validate(),
          throwsArgumentError);
      expect(() => const ControlMapping(channel: 17, controller: 7).validate(),
          throwsArgumentError);
      expect(() => const ControlMapping(channel: 1, controller: 7).validate(),
          returnsNormally);
      expect(() => const ControlMapping(channel: 16, controller: 7).validate(),
          returnsNormally);
    });

    test('validates controller range', () {
      expect(() => const ControlMapping(channel: 1, controller: -1).validate(),
          throwsArgumentError);
      expect(() => const ControlMapping(channel: 1, controller: 128).validate(),
          throwsArgumentError);
      expect(() => const ControlMapping(channel: 1, controller: 0).validate(),
          returnsNormally);
      expect(() => const ControlMapping(channel: 1, controller: 127).validate(),
          returnsNormally);
    });
  });

  group('ControlBank', () {
    test('creates bank with controls', () {
      final controls = [
        MidiControl(
          id: '1',
          label: 'Fader 1',
          type: MidiControlType.fader,
          mapping: const ControlMapping(channel: 1, controller: 7),
        ),
        MidiControl(
          id: '2',
          label: 'Fader 2',
          type: MidiControlType.fader,
          mapping: const ControlMapping(channel: 1, controller: 8),
        ),
      ];

      final bank = ControlBank(
        id: 'bank-1',
        name: 'Test Bank',
        controls: controls,
      );

      expect(bank.id, 'bank-1');
      expect(bank.name, 'Test Bank');
      expect(bank.controls.length, 2);
    });

    test('finds control by id', () {
      final controls = [
        MidiControl(
          id: '1',
          label: 'Fader 1',
          type: MidiControlType.fader,
          mapping: const ControlMapping(channel: 1, controller: 7),
        ),
        MidiControl(
          id: '2',
          label: 'Fader 2',
          type: MidiControlType.fader,
          mapping: const ControlMapping(channel: 1, controller: 8),
        ),
      ];

      final bank = ControlBank(
        id: 'bank-1',
        name: 'Test Bank',
        controls: controls,
      );

      final found = bank.controls.firstWhere((c) => c.id == '2');
      expect(found.label, 'Fader 2');
    });
  });

  group('ControlBankTemplates', () {
    test('instrument template has expected controls', () {
      final bank = ControlBankTemplates.instrument();
      expect(bank.name, 'Instrument');
      expect(bank.controls.length, greaterThan(0));

      // Check for layer volumes
      final layerVolumes = bank.controls
          .where((c) => c.id.startsWith('layer-vol'))
          .toList();
      expect(layerVolumes.length, 8);

      // Check for layer toggles
      final layerToggles = bank.controls
          .where((c) => c.id.startsWith('layer-toggle'))
          .toList();
      expect(layerToggles.length, 8);

      // Check for pads (pad-1 to pad-12, not pad-volume)
      final pads = bank.controls
          .where((c) => c.id.startsWith('pad-') && c.id != 'pad-volume')
          .toList();
      expect(pads.length, 12);

      // Check for pad volume
      final padVolume = bank.controls.firstWhere((c) => c.id == 'pad-volume');
      expect(padVolume.type, MidiControlType.fader);
      expect(padVolume.mapping.controller, 48);
    });

    test('mixer template has expected controls', () {
      final bank = ControlBankTemplates.mixer();
      expect(bank.name, 'Mixer');
      expect(bank.controls.length, 17); // 8 faders + 8 pan knobs + master
    });

    test('transport template has expected controls', () {
      final bank = ControlBankTemplates.transport();
      expect(bank.name, 'Transport');
      expect(bank.controls.length, 3); // Play, Stop, Record
    });
  });

  group('MidiControlType', () {
    test('all types are supported', () {
      expect(MidiControlType.values.length, 6);
      expect(MidiControlType.values.contains(MidiControlType.fader), isTrue);
      expect(MidiControlType.values.contains(MidiControlType.knob), isTrue);
      expect(MidiControlType.values.contains(MidiControlType.momentaryButton), isTrue);
      expect(MidiControlType.values.contains(MidiControlType.toggleButton), isTrue);
      expect(MidiControlType.values.contains(MidiControlType.latchButton), isTrue);
      expect(MidiControlType.values.contains(MidiControlType.xyPad), isTrue);
    });
  });
}
