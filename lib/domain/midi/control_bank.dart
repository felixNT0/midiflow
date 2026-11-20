import 'midi_control.dart';

/// A named page of controls on the Play surface (TouchDAW-style "mode").
/// Banks let one device hold e.g. an instrument page and a mixer page.
class ControlBank {
  const ControlBank({
    required this.id,
    required this.name,
    this.controls = const [],
  });

  final String id;
  final String name;
  final List<MidiControl> controls;

  ControlBank copyWith({String? name, List<MidiControl>? controls}) {
    return ControlBank(
      id: id,
      name: name ?? this.name,
      controls: controls ?? this.controls,
    );
  }
}

/// Built-in bank layouts. These are starting points — every mapping stays
/// editable in Assign.
abstract final class ControlBankTemplates {
  /// Chromatic key names shown on the continuous pads (one octave).
  static const _padNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  /// Default instrument page: multi-part performance surface.
  ///
  /// Layer volume faders (CC20-27) are the primary controls for Kontakt
  /// libraries. Performance knobs and part controls follow.
  static ControlBank instrument() {
    final controls = <MidiControl>[];

    // Layer volume faders FIRST (primary controls for Kontakt)
    for (var i = 1; i <= 8; i++) {
      controls.add(
        MidiControl(
          id: 'layer-vol-$i',
          label: 'Layer $i',
          type: MidiControlType.fader,
          mapping: ControlMapping(channel: 1, controller: 19 + i),
          normalizedValue: 0.8,
        ),
      );
    }

    // Layer on/off toggles — CC28-35 on channel 1, forwarded to the
    // plugin MIDI port so Kontakt/VST layer mute buttons can Learn them.
    for (var i = 1; i <= 8; i++) {
      controls.add(
        MidiControl(
          id: 'layer-toggle-$i',
          label: 'L$i On/Off',
          type: MidiControlType.toggleButton,
          mapping: ControlMapping(channel: 1, controller: 27 + i),
        ),
      );
    }

    // Continuous pads — CC36-47 on channel 1, forwarded to the plugin
    // MIDI port so each pad can be assigned to the Kontakt library's
    // pad/drone controls. Labels show the chromatic key names.
    for (var i = 1; i <= 12; i++) {
      controls.add(
        MidiControl(
          id: 'pad-$i',
          label: _padNames[i - 1],
          type: MidiControlType.toggleButton,
          mapping: ControlMapping(channel: 1, controller: 35 + i),
        ),
      );
    }

    // Part volume faders and pan knobs (for multi-part instruments)
    for (var i = 1; i <= 8; i++) {
      controls.add(
        MidiControl(
          id: 'part-vol-$i',
          label: 'Vol $i',
          type: MidiControlType.fader,
          mapping: ControlMapping(channel: i, controller: 7),
          normalizedValue: 0.8,
        ),
      );
      controls.add(
        MidiControl(
          id: 'part-pan-$i',
          label: 'Pan $i',
          type: MidiControlType.knob,
          mapping: ControlMapping(channel: i, controller: 10),
          normalizedValue: 0.5,
        ),
      );
    }

    return ControlBank(
      id: 'bank-instrument',
      name: 'Instrument',
      controls: controls,
    );
  }

  /// Mixer page: 8 channel-volume faders (CC7) and 8 pan knobs (CC10) on
  /// MIDI channels 9-16. The FL Studio device script maps channel N to
  /// mixer track N-8, so channel 9 drives mixer track 1 … channel 16
  /// drives track 8. Channels 9-16 keep these clear of instrument-bank
  /// CCs on channel 1.
  static ControlBank mixer() {
    final controls = <MidiControl>[
      // Master volume — the FL Studio script maps channel 16 / CC14 to
      // mixer track 0 (the Master fader).
      MidiControl(
        id: 'master-vol',
        label: 'Master',
        type: MidiControlType.fader,
        mapping: const ControlMapping(channel: 16, controller: 14),
        normalizedValue: 0.8,
      ),
    ];
    for (var i = 1; i <= 8; i++) {
      controls.add(
        MidiControl(
          id: 'mix-vol-$i',
          label: 'Vol $i',
          type: MidiControlType.fader,
          mapping: ControlMapping(channel: i + 8, controller: 7),
          normalizedValue: 0.78,
        ),
      );
      controls.add(
        MidiControl(
          id: 'mix-pan-$i',
          label: 'Pan $i',
          type: MidiControlType.knob,
          mapping: ControlMapping(channel: i + 8, controller: 10),
          normalizedValue: 0.5,
        ),
      );
    }
    return ControlBank(id: 'bank-mixer', name: 'Mixer', controls: controls);
  }

  /// Transport page for FL Studio: buttons on channel 16 that the device
  /// script maps to play/pause, stop and record.
  static ControlBank transport() => ControlBank(
    id: 'bank-transport',
    name: 'Transport',
    controls: [
      MidiControl(
        id: 't-play',
        label: 'Play/Pause',
        type: MidiControlType.momentaryButton,
        mapping: const ControlMapping(channel: 16, controller: 30),
      ),
      MidiControl(
        id: 't-stop',
        label: 'Stop',
        type: MidiControlType.momentaryButton,
        mapping: const ControlMapping(channel: 16, controller: 31),
      ),
      MidiControl(
        id: 't-record',
        label: 'Record',
        type: MidiControlType.momentaryButton,
        mapping: const ControlMapping(channel: 16, controller: 32),
      ),
    ],
  );

  /// Performance page: instrument performance knobs, XY pad and sustain.
  /// These are "lead" controls — they follow the Part selector on the
  /// Instrument bank and target the channel hosting the instrument.
  static ControlBank performance() {
    return ControlBank(
      id: 'bank-performance',
      name: 'Performance',
      controls: [
        MidiControl(
          id: 'modulation',
          label: 'Modulation',
          type: MidiControlType.knob,
          mapping: const ControlMapping(channel: 1, controller: 1),
        ),
        MidiControl(
          id: 'expression',
          label: 'Expression',
          type: MidiControlType.knob,
          mapping: const ControlMapping(channel: 1, controller: 11),
          normalizedValue: 1.0,
        ),
        MidiControl(
          id: 'filter-cutoff',
          label: 'Cutoff',
          type: MidiControlType.knob,
          mapping: const ControlMapping(channel: 1, controller: 74),
        ),
        MidiControl(
          id: 'filter-resonance',
          label: 'Resonance',
          type: MidiControlType.knob,
          mapping: const ControlMapping(channel: 1, controller: 71),
        ),
        MidiControl(
          id: 'filter-env-amount',
          label: 'Filter Env',
          type: MidiControlType.knob,
          mapping: const ControlMapping(channel: 1, controller: 80),
        ),
        MidiControl(
          id: 'attack',
          label: 'Attack',
          type: MidiControlType.knob,
          mapping: const ControlMapping(channel: 1, controller: 73),
        ),
        MidiControl(
          id: 'decay',
          label: 'Decay',
          type: MidiControlType.knob,
          mapping: const ControlMapping(channel: 1, controller: 75),
        ),
        MidiControl(
          id: 'release',
          label: 'Release',
          type: MidiControlType.knob,
          mapping: const ControlMapping(channel: 1, controller: 72),
        ),
        MidiControl(
          id: 'portamento',
          label: 'Portamento',
          type: MidiControlType.knob,
          mapping: const ControlMapping(channel: 1, controller: 5),
        ),
        MidiControl(
          id: 'detune',
          label: 'Detune',
          type: MidiControlType.knob,
          mapping: const ControlMapping(channel: 1, controller: 18),
        ),
        MidiControl(
          id: 'xy-expression',
          label: 'XY Pad',
          type: MidiControlType.xyPad,
          mapping: const ControlMapping(channel: 1, controller: 16),
          xMapping: const ControlMapping(channel: 1, controller: 16),
          yMapping: const ControlMapping(channel: 1, controller: 17),
        ),
        MidiControl(
          id: 'sustain',
          label: 'Sustain',
          type: MidiControlType.momentaryButton,
          mapping: const ControlMapping(channel: 1, controller: 64),
        ),
      ],
    );
  }

  /// Drum pads page: 16 momentary pads sending CC48-63 on channel 1.
  /// Assignable to drum articulations, choke groups and drum FX in the
  /// Kontakt/VST library via Learn MIDI CC.
  static ControlBank drums() {
    return ControlBank(
      id: 'bank-drums',
      name: 'Drums',
      controls: [
        for (var i = 1; i <= 16; i++)
          MidiControl(
            id: 'drum-$i',
            label: 'Pad $i',
            type: MidiControlType.momentaryButton,
            mapping: ControlMapping(channel: 1, controller: 47 + i),
          ),
      ],
    );
  }

  /// Effects page: assignable knobs (CC96-103) and on/off toggles
  /// (CC104-107) for the Kontakt/VST library's effect parameters —
  /// reverb, delay, modulation FX, drive and tone.
  static ControlBank effects() {
    MidiControl knob(String id, String label, int cc) => MidiControl(
          id: id,
          label: label,
          type: MidiControlType.knob,
          mapping: ControlMapping(channel: 1, controller: cc),
        );
    MidiControl toggle(String id, String label, int cc) => MidiControl(
          id: id,
          label: label,
          type: MidiControlType.toggleButton,
          mapping: ControlMapping(channel: 1, controller: cc),
        );
    return ControlBank(
      id: 'bank-effects',
      name: 'Effects',
      controls: [
        knob('fx-rev-size', 'Rev Size', 96),
        knob('fx-rev-decay', 'Rev Decay', 97),
        knob('fx-delay-time', 'Delay Time', 98),
        knob('fx-delay-fdbk', 'Delay Fdbk', 99),
        knob('fx-chorus', 'Chorus', 100),
        knob('fx-phaser', 'Phaser', 101),
        knob('fx-drive', 'Drive', 102),
        knob('fx-tone', 'Tone', 103),
        toggle('fx-rev-on', 'Rev On', 104),
        toggle('fx-dly-on', 'Dly On', 105),
        toggle('fx-cho-on', 'Cho On', 106),
        toggle('fx-pha-on', 'Pha On', 107),
      ],
    );
  }

  static ControlBank empty(String name, {required String id}) =>
      ControlBank(id: id, name: name);
}
