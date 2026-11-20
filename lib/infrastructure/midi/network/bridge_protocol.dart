import 'dart:convert';

/// Versioned line-delimited JSON protocol between the MIDIFlow mobile app
/// (client) and the MIDIFlow desktop bridge (server).
///
/// Transport: TCP, UTF-8, one JSON object per line terminated by '\n'.
/// The socket is transport only — the bridge converts messages into real OS
/// MIDI via a virtual endpoint; it is never itself a MIDI device.

const int bridgeProtocolVersion = 1;
const int bridgeDefaultPort = 8765;

/// Maximum accepted message size (bytes) — guards against abusive payloads.
const int bridgeMaxLineBytes = 4096;

/// Simple per-connection rate limit: messages per second.
const int bridgeMaxMessagesPerSecond = 240;

enum BridgeMessageType {
  hello,
  welcome,
  cc,
  noteOn,
  noteOff,
  ping,
  pong,
  error,
  bye,
  unknown,
}

/// A decoded bridge message. Exactly one payload family is populated.
class BridgeMessage {
  const BridgeMessage._({
    required this.type,
    this.version,
    this.token,
    this.controllerId,
    this.controllerName,
    this.channel,
    this.controller,
    this.value,
    this.note,
    this.velocity,
    this.noteOn,
    this.message,
    this.assignedId,
  });

  final BridgeMessageType type;
  final int? version;
  final String? token;
  final String? controllerId;
  final String? controllerName;
  final int? channel;
  final int? controller;
  final int? value;
  final int? note;
  final int? velocity;
  final bool? noteOn;
  final String? message;
  final String? assignedId;

  factory BridgeMessage.hello({
    required String token,
    required String controllerId,
    String? controllerName,
  }) {
    return BridgeMessage._(
      type: BridgeMessageType.hello,
      version: bridgeProtocolVersion,
      token: token,
      controllerId: controllerId,
      controllerName: controllerName,
    );
  }

  factory BridgeMessage.welcome({required String assignedId}) {
    return BridgeMessage._(
      type: BridgeMessageType.welcome,
      version: bridgeProtocolVersion,
      assignedId: assignedId,
    );
  }

  factory BridgeMessage.cc({
    required int channel,
    required int controller,
    required int value,
  }) {
    return BridgeMessage._(
      type: BridgeMessageType.cc,
      channel: channel,
      controller: controller,
      value: value,
    );
  }

  factory BridgeMessage.note({
    required bool on,
    required int channel,
    required int note,
    required int velocity,
  }) {
    return BridgeMessage._(
      type: on ? BridgeMessageType.noteOn : BridgeMessageType.noteOff,
      channel: channel,
      note: note,
      velocity: velocity,
      noteOn: on,
    );
  }

  factory BridgeMessage.ping() =>
      const BridgeMessage._(type: BridgeMessageType.ping);

  factory BridgeMessage.pong() =>
      const BridgeMessage._(type: BridgeMessageType.pong);

  factory BridgeMessage.error(String message) =>
      BridgeMessage._(type: BridgeMessageType.error, message: message);

  factory BridgeMessage.bye() =>
      const BridgeMessage._(type: BridgeMessageType.bye);

  /// Encodes to a single protocol line (no trailing newline).
  String encode() {
    final map = <String, Object?>{'v': version ?? bridgeProtocolVersion};
    switch (type) {
      case BridgeMessageType.hello:
        map['t'] = 'hello';
        map['token'] = token;
        map['id'] = controllerId;
        map['name'] = controllerName;
      case BridgeMessageType.welcome:
        map['t'] = 'welcome';
        map['id'] = assignedId;
      case BridgeMessageType.cc:
        map['t'] = 'cc';
        map['ch'] = channel;
        map['cc'] = controller;
        map['val'] = value;
      case BridgeMessageType.noteOn:
      case BridgeMessageType.noteOff:
        map['t'] = type == BridgeMessageType.noteOn ? 'noteOn' : 'noteOff';
        map['ch'] = channel;
        map['n'] = note;
        map['vel'] = velocity;
      case BridgeMessageType.ping:
        map['t'] = 'ping';
      case BridgeMessageType.pong:
        map['t'] = 'pong';
      case BridgeMessageType.error:
        map['t'] = 'error';
        map['msg'] = message;
      case BridgeMessageType.bye:
        map['t'] = 'bye';
      case BridgeMessageType.unknown:
        map['t'] = 'unknown';
    }
    return jsonEncode(map);
  }

  /// Decodes one line. Returns null for malformed input; returns an
  /// `unknown`-typed message for valid JSON with an unrecognized type.
  static BridgeMessage? decode(String line) {
    if (line.trim().isEmpty) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(line);
    } catch (_) {
      return null;
    }
    if (decoded is! Map) return null;
    final map = decoded.cast<String, Object?>();

    int? intField(String key) {
      final v = map[key];
      if (v is int) return v;
      if (v is num) return v.round();
      return null;
    }

    String? strField(String key) {
      final v = map[key];
      return v is String ? v : null;
    }

    final version = intField('v');
    if (version != null && version > bridgeProtocolVersion) {
      return BridgeMessage._(
        type: BridgeMessageType.error,
        message:
            'Unsupported protocol version $version '
            '(max $bridgeProtocolVersion).',
      );
    }

    switch (map['t']) {
      case 'hello':
        final token = strField('token');
        final id = strField('id');
        if (token == null || id == null) return null;
        return BridgeMessage._(
          type: BridgeMessageType.hello,
          version: version,
          token: token,
          controllerId: id,
          controllerName: strField('name'),
        );
      case 'welcome':
        return BridgeMessage._(
          type: BridgeMessageType.welcome,
          version: version,
          assignedId: strField('id'),
        );
      case 'cc':
        final ch = intField('ch');
        final cc = intField('cc');
        final v = intField('val');
        if (ch == null || cc == null || v == null) return null;
        return BridgeMessage._(
          type: BridgeMessageType.cc,
          channel: ch,
          controller: cc,
          value: v,
        );
      case 'noteOn':
      case 'noteOff':
        final ch = intField('ch');
        final n = intField('n');
        final v = intField('vel');
        if (ch == null || n == null || v == null) return null;
        return BridgeMessage._(
          type: map['t'] == 'noteOn'
              ? BridgeMessageType.noteOn
              : BridgeMessageType.noteOff,
          channel: ch,
          note: n,
          velocity: v,
          noteOn: map['t'] == 'noteOn',
        );
      case 'ping':
        return const BridgeMessage._(type: BridgeMessageType.ping);
      case 'pong':
        return const BridgeMessage._(type: BridgeMessageType.pong);
      case 'error':
        return BridgeMessage._(
          type: BridgeMessageType.error,
          message: strField('msg'),
        );
      case 'bye':
        return const BridgeMessage._(type: BridgeMessageType.bye);
      default:
        return const BridgeMessage._(type: BridgeMessageType.unknown);
    }
  }
}
