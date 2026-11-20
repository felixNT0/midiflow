import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../midi_device_model.dart';
import '../midi_service.dart';
import 'bridge_protocol.dart';

/// A connected bridge client as seen by the server.
class BridgeClientInfo {
  const BridgeClientInfo({
    required this.id,
    required this.name,
    required this.connectedAt,
    required this.messagesReceived,
  });

  final String id;
  final String name;
  final DateTime connectedAt;
  final int messagesReceived;
}

/// TCP server that accepts MIDIFlow mobile clients and injects their control
/// messages into a real OS MIDI endpoint (virtual source on Apple platforms).
///
/// Security model: local network only, explicit pairing token, per-client
/// rate limiting, protocol version check. The socket is never presented as a
/// MIDI device — only the virtual endpoint is.
class BridgeServer {
  BridgeServer({required this.midiService, this.onClientChanged});

  final MidiService midiService;
  final void Function()? onClientChanged;

  ServerSocket? _server;
  MidiDeviceInfo? _endpoint;
  final Map<Socket, _ClientSession> _sessions = {};
  String? _token;
  int _port = bridgeDefaultPort;
  bool _running = false;

  bool get isRunning => _running;
  String? get token => _token;
  int get port => _port;
  MidiDeviceInfo? get endpoint => _endpoint;
  List<BridgeClientInfo> get clients => [
    for (final s in _sessions.values)
      BridgeClientInfo(
        id: s.id,
        name: s.name,
        connectedAt: s.connectedAt,
        messagesReceived: s.messagesReceived,
      ),
  ];

  /// Starts listening and creates the virtual MIDI endpoint.
  ///
  /// [token] is the pairing secret shown to the user; clients must present it
  /// in their `hello` message.
  Future<void> start({
    required String token,
    int port = bridgeDefaultPort,
  }) async {
    if (_running) return;
    _token = token;
    _port = port;

    _endpoint = await midiService.createBridgeEndpoint();

    _server = await ServerSocket.bind(InternetAddress.anyIPv4, port);
    _running = true;
    _server!.listen(_handleConnection, onError: (_) {}, cancelOnError: false);
  }

  Future<void> stop() async {
    _running = false;
    for (final socket in _sessions.keys.toList()) {
      socket.destroy();
    }
    _sessions.clear();
    await _server?.close();
    _server = null;
    _endpoint = null;
    _token = null;
    onClientChanged?.call();
  }

  void _handleConnection(Socket socket) {
    final session = _ClientSession(socket: socket);
    _sessions[socket] = session;
    onClientChanged?.call();

    utf8.decoder
        .bind(socket)
        .transform(const LineSplitter())
        .listen(
          (line) => _handleLine(session, line),
          onError: (_) {},
          onDone: () => _dropClient(socket),
          cancelOnError: false,
        );
    socket.done.then((_) => _dropClient(socket)).ignore();
  }

  void _handleLine(_ClientSession session, String line) {
    if (line.length > bridgeMaxLineBytes) {
      _sendError(session, 'Message too large.');
      return;
    }

    // Rate limit: sliding 1-second window per connection.
    final now = DateTime.now();
    session.windowStart ??= now;
    if (now.difference(session.windowStart!) >= const Duration(seconds: 1)) {
      session.windowStart = now;
      session.messagesThisWindow = 0;
    }
    if (++session.messagesThisWindow > bridgeMaxMessagesPerSecond) {
      return; // silently drop floods
    }

    final message = BridgeMessage.decode(line);
    if (message == null) {
      _sendError(session, 'Malformed message.');
      return;
    }

    if (!session.authenticated) {
      _handleHandshake(session, message);
      return;
    }
    session.messagesReceived++;

    switch (message.type) {
      case BridgeMessageType.cc:
        _injectControlChange(message);
      case BridgeMessageType.noteOn:
      case BridgeMessageType.noteOff:
        _injectNote(message);
      case BridgeMessageType.ping:
        _send(session, BridgeMessage.pong());
      case BridgeMessageType.pong:
        break;
      case BridgeMessageType.bye:
        session.socket.destroy();
      case BridgeMessageType.hello:
        _sendError(session, 'Already authenticated.');
      case BridgeMessageType.welcome:
      case BridgeMessageType.error:
      case BridgeMessageType.unknown:
        break;
    }
  }

  void _handleHandshake(_ClientSession session, BridgeMessage message) {
    if (message.type == BridgeMessageType.error) {
      _sendError(session, message.message ?? 'Protocol error.');
      session.socket.destroy();
      return;
    }
    if (message.type != BridgeMessageType.hello) {
      _sendError(session, 'Expected hello.');
      session.socket.destroy();
      return;
    }
    if (message.token != _token) {
      _sendError(session, 'Pairing token rejected.');
      session.socket.destroy();
      return;
    }
    session
      ..authenticated = true
      ..id = message.controllerId ?? 'unknown'
      ..name = message.controllerName ?? message.controllerId ?? 'Controller';
    _send(session, BridgeMessage.welcome(assignedId: session.id));
    onClientChanged?.call();
  }

  void _injectControlChange(BridgeMessage message) {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    final ch = message.channel;
    final cc = message.controller;
    final v = message.value;
    if (ch == null || cc == null || v == null) return;
    if (ch < 1 || ch > 16 || cc < 0 || cc > 127 || v < 0 || v > 127) {
      return;
    }
    unawaited(
      midiService
          .sendControlChange(
            device: endpoint,
            channel: ch,
            controller: cc,
            value: v,
          )
          .catchError((_) {}),
    );
  }

  void _injectNote(BridgeMessage message) {
    final endpoint = _endpoint;
    if (endpoint == null) return;
    final ch = message.channel;
    final n = message.note;
    final v = message.velocity;
    if (ch == null || n == null || v == null) return;
    if (ch < 1 || ch > 16 || n < 0 || n > 127 || v < 0 || v > 127) return;
    final protocolChannel = ch - 1;
    final status = message.noteOn == true ? 0x90 : 0x80;
    final data = Uint8List.fromList([status + protocolChannel, n, v]);
    unawaited(midiService.sendRaw(data, device: endpoint).catchError((_) {}));
  }

  void _send(_ClientSession session, BridgeMessage message) {
    try {
      session.socket.write('${message.encode()}\n');
    } catch (_) {
      _dropClient(session.socket);
    }
  }

  void _sendError(_ClientSession session, String text) {
    _send(session, BridgeMessage.error(text));
  }

  void _dropClient(Socket socket) {
    final session = _sessions.remove(socket);
    if (session != null) {
      try {
        socket.destroy();
      } catch (_) {}
      onClientChanged?.call();
    }
  }
}

class _ClientSession {
  _ClientSession({required this.socket});

  final Socket socket;
  bool authenticated = false;
  String id = '';
  String name = '';
  DateTime connectedAt = DateTime.now();
  int messagesReceived = 0;
  int messagesThisWindow = 0;
  DateTime? windowStart;
}
