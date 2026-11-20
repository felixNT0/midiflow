import '../../infrastructure/midi/midi_message_model.dart'
    show
        midiMaxValue,
        midiMinValue,
        validateControllerNumber,
        validateMidiChannel,
        validateMidiValue;

/// Types of on-screen controls.
enum MidiControlType {
  fader,
  knob,
  momentaryButton,
  toggleButton,
  latchButton,
  xyPad,
}

/// A single MIDI output mapping: channel + controller + scaling range.
class ControlMapping {
  const ControlMapping({
    this.channel = 1,
    this.controller = 0,
    this.minValue = midiMinValue,
    this.maxValue = midiMaxValue,
    this.inverted = false,
  });

  /// User-facing channel 1-16.
  final int channel;

  /// CC controller number 0-127.
  final int controller;
  final int minValue;
  final int maxValue;
  final bool inverted;

  ControlMapping copyWith({
    int? channel,
    int? controller,
    int? minValue,
    int? maxValue,
    bool? inverted,
  }) {
    return ControlMapping(
      channel: channel ?? this.channel,
      controller: controller ?? this.controller,
      minValue: minValue ?? this.minValue,
      maxValue: maxValue ?? this.maxValue,
      inverted: inverted ?? this.inverted,
    );
  }

  void validate() {
    validateMidiChannel(channel);
    validateControllerNumber(controller);
    validateMidiValue(minValue, name: 'minValue');
    validateMidiValue(maxValue, name: 'maxValue');
    if (minValue > maxValue) {
      throw ArgumentError('minValue must be <= maxValue.');
    }
  }
}

/// A user-configurable control on the Play surface.
///
/// [normalizedValue] is always 0.0-1.0 (post-inversion UI value maps to MIDI
/// through [mapping]). Buttons interpret min/max of their mapping as the
/// off/on values. XY pads carry two independent mappings.
class MidiControl {
  MidiControl({
    required this.id,
    required this.label,
    required this.type,
    ControlMapping? mapping,
    this.xMapping,
    this.yMapping,
    double normalizedValue = 0.0,
    double yNormalized = 0.5,
  }) : mapping = mapping ?? const ControlMapping(),
       normalizedValue = normalizedValue.clamp(0.0, 1.0),
       yNormalized = yNormalized.clamp(0.0, 1.0);

  final String id;
  String label;
  final MidiControlType type;
  final ControlMapping mapping;
  final ControlMapping? xMapping;
  final ControlMapping? yMapping;
  double normalizedValue;

  /// Secondary axis value for XY pads (normalized 0.0-1.0). Unused otherwise.
  double yNormalized;

  bool get isAxisControl => type == MidiControlType.xyPad;

  /// MIDI value for the primary mapping at the current normalized value.
  int get currentMidiValue => normalizedToMidi(normalizedValue, mapping);

  MidiControl copyWith({
    String? label,
    ControlMapping? mapping,
    ControlMapping? xMapping,
    ControlMapping? yMapping,
    double? normalizedValue,
    double? yNormalized,
    bool clearAxes = false,
  }) {
    return MidiControl(
      id: id,
      label: label ?? this.label,
      type: type,
      mapping: mapping ?? this.mapping,
      xMapping: clearAxes ? null : (xMapping ?? this.xMapping),
      yMapping: clearAxes ? null : (yMapping ?? this.yMapping),
      normalizedValue: normalizedValue ?? this.normalizedValue,
      yNormalized: yNormalized ?? this.yNormalized,
    );
  }
}

/// Clamps a UI value into the normalized 0.0-1.0 range.
double clampNormalized(double value) => value.clamp(0.0, 1.0);

/// Converts a normalized UI value (0.0-1.0) to a MIDI value using the
/// mapping's min/max range and inversion flag.
///
/// `midiValue = round(min + normalized * (max - min))`, with inversion
/// applied before scaling.
int normalizedToMidi(double normalized, ControlMapping mapping) {
  final n = clampNormalized(normalized);
  final effective = mapping.inverted ? 1.0 - n : n;
  final span = mapping.maxValue - mapping.minValue;
  final raw = mapping.minValue + effective * span;
  return raw.round().clamp(mapping.minValue, mapping.maxValue);
}

/// Converts a MIDI value back to a normalized UI value (0.0-1.0).
double midiToNormalized(int midiValue, ControlMapping mapping) {
  if (mapping.maxValue == mapping.minValue) return 0.0;
  final clamped = midiValue.clamp(mapping.minValue, mapping.maxValue);
  final t =
      (clamped - mapping.minValue) / (mapping.maxValue - mapping.minValue);
  return mapping.inverted ? 1.0 - t : t;
}

/// Returns the "on" MIDI value for a button control (max of its mapping,
/// honouring inversion through the normalized domain: on = normalized 1.0).
int buttonOnValue(ControlMapping mapping) => normalizedToMidi(1.0, mapping);

/// Returns the "off" MIDI value for a button control.
int buttonOffValue(ControlMapping mapping) => normalizedToMidi(0.0, mapping);
