import 'dart:typed_data';

/// MIDI value range constants (spec: values are 0-127, channels 1-16).
const int midiMinValue = 0;
const int midiMaxValue = 127;
const int midiMinChannel = 1;
const int midiMaxChannel = 16;

/// Validates and clamps a MIDI data value (0-127).
int validateMidiValue(int value, {String name = 'value'}) {
  if (value < midiMinValue || value > midiMaxValue) {
    throw ArgumentError.value(
      value,
      name,
      'MIDI values must be in the range $midiMinValue-$midiMaxValue.',
    );
  }
  return value;
}

/// Validates a user-facing MIDI channel (1-16) and returns the protocol
/// zero-based channel value.
int validateMidiChannel(int channel, {String name = 'channel'}) {
  if (channel < midiMinChannel || channel > midiMaxChannel) {
    throw ArgumentError.value(
      channel,
      name,
      'MIDI channels must be in the range $midiMinChannel-$midiMaxChannel.',
    );
  }
  return channel - 1;
}

/// Validates a CC controller number (0-127).
int validateControllerNumber(int controller, {String name = 'controller'}) {
  return validateMidiValue(controller, name: name);
}

/// Builds the raw bytes for a MIDI Control Change message.
///
/// [channel] is user-facing (1-16); it is converted to the protocol
/// zero-based channel internally. [controller] and [value] must be 0-127.
Uint8List buildControlChangeBytes({
  required int channel,
  required int controller,
  required int value,
}) {
  final protocolChannel = validateMidiChannel(channel);
  final cc = validateControllerNumber(controller);
  final v = validateMidiValue(value);
  return Uint8List.fromList([0xB0 + protocolChannel, cc, v]);
}

/// Kinds of MIDI messages surfaced to the application.
enum MidiMessageKind {
  controlChange,
  noteOn,
  noteOff,
  pitchBend,
  programChange,
  channelPressure,
  polyPressure,
  aftertouch,
  system,
  sysex,
  other,
}

/// Direction of a logged MIDI message.
enum MidiMessageDirection { incoming, outgoing }

/// Platform-neutral representation of a MIDI message for logging/monitoring.
class MidiIncomingMessage {
  const MidiIncomingMessage({
    required this.timestamp,
    required this.direction,
    required this.sourceDevice,
    required this.kind,
    this.channel,
    this.controller,
    this.note,
    this.value,
    this.rawBytes,
    this.detail,
  });

  final DateTime timestamp;
  final MidiMessageDirection direction;
  final String sourceDevice;
  final MidiMessageKind kind;

  /// User-facing channel (1-16), or null for non-channel messages.
  final int? channel;
  final int? controller;
  final int? note;
  final int? value;
  final String? rawBytes;
  final String? detail;

  String describe() {
    final buffer = StringBuffer()
      ..write('[${timestamp.toIso8601String()}] ')
      ..write(direction == MidiMessageDirection.incoming ? 'IN ' : 'OUT ')
      ..write('$sourceDevice ')
      ..write(kind.name);
    if (channel != null) buffer.write(' ch$channel');
    if (controller != null) buffer.write(' cc$controller');
    if (note != null) buffer.write(' note$note');
    if (value != null) buffer.write('=$value');
    if (detail != null) buffer.write(' ($detail)');
    return buffer.toString();
  }
}
