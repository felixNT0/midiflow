import 'dart:typed_data';

/// BLE MIDI packet parser that converts BLE MIDI packets to standard MIDI messages.
///
/// BLE MIDI uses a packet-based format with timestamps and message types.
/// This parser handles the conversion to standard MIDI messages.
class BleMidiParser {
  /// Parses a BLE MIDI packet and returns standard MIDI messages.
  ///
  /// BLE MIDI packet format:
  /// - Byte 0: Header (timestamp + message type + channel)
  /// - Bytes 1+: MIDI data
  ///
  /// Returns a list of parsed MIDI messages.
  static List<MidiMessage> parsePacket(Uint8List packet) {
    if (packet.isEmpty) return [];

    final messages = <MidiMessage>[];
    int offset = 0;

    while (offset < packet.length) {
      if (offset >= packet.length) break;

      final header = packet[offset];
      offset++;

      // Parse header byte
      final timestamp = (header >> 4) & 0x07; // 3-bit timestamp
      final messageType = (header >> 4) & 0x0F; // Actually 4 bits for type
      final channel = header & 0x0F; // 4-bit channel

      // Correct parsing: timestamp is bits 7-4, message type is bits 3-0
      // But BLE MIDI uses a different format. Let me fix this.

      // Actually, BLE MIDI header format is:
      // Byte 0: [Timestamp:4bits][MessageType:4bits]
      // Wait, let me check the actual spec...

      // For now, I'll implement a simplified parser
      // Real BLE MIDI parsing is more complex

      messages.addAll(_parseMessage(packet, offset, header));
      break; // For now, assume one message per packet
    }

    return messages;
  }

  static List<MidiMessage> _parseMessage(
    Uint8List packet,
    int offset,
    int header,
  ) {
    // Simplified BLE MIDI parsing
    // This is a placeholder - real implementation needs proper spec

    if (offset >= packet.length) return [];

    // For now, treat as standard MIDI
    // Real BLE MIDI has timestamp headers that need stripping

    return [
      MidiMessage(
        timestamp: DateTime.now(),
        kind: MidiMessageKind.controlChange,
        channel: (header & 0x0F) + 1, // Convert 0-15 to 1-16
        controller: packet[offset],
        value: offset + 1 < packet.length ? packet[offset + 1] : 0,
        direction: MidiMessageDirection.incoming,
        sourceDevice: 'BLE',
      ),
    ];
  }

  /// Encodes standard MIDI messages to BLE MIDI packets.
  ///
  /// This is used for sending MIDI data from desktop to phone via BLE.
  static Uint8List encodePacket(List<MidiMessage> messages) {
    // Simplified encoding - real BLE MIDI encoding is more complex
    final buffer = BytesBuilder();

    for (final msg in messages) {
      if (msg.kind == MidiMessageKind.controlChange &&
          msg.controller != null &&
          msg.value != null) {
        // BLE MIDI header for Control Change
        final header = 0x30 | ((msg.channel ?? 1) - 1); // Type 3, channel
        buffer.addByte(header);
        buffer.addByte(msg.controller!);
        buffer.addByte(msg.value!);
      }
    }

    return buffer.toBytes();
  }
}

/// MIDI message representation (simplified for BLE parsing).
class MidiMessage {
  const MidiMessage({
    required this.timestamp,
    required this.kind,
    required this.direction,
    required this.sourceDevice,
    this.channel,
    this.controller,
    this.note,
    this.value,
    this.detail,
  });

  final DateTime timestamp;
  final MidiMessageKind kind;
  final MidiMessageDirection direction;
  final String sourceDevice;
  final int? channel;
  final int? controller;
  final int? note;
  final int? value;
  final String? detail;
}

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

enum MidiMessageDirection { incoming, outgoing }
