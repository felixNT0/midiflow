import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'bridge_protocol.dart';

enum BridgeClientStatus { disconnected, connecting, connected, error }

/// Events surfaced to the UI layer.
class BridgeClientEvent {
  const BridgeClientEvent(this.status, [this.message]);

  final BridgeClientStatus status;
  final String? message;
}

/// Mobile-side TCP client for the MIDIFlow desktop bridge.
///
/// Connects, performs the token handshake, then streams CC/note messages.
/// Reconnection is manual in this milestone.
class BridgeClient {
  BridgeClient({String? controllerId})
    : controllerId =
          controllerId ??
          'ctl-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
              '-${Random.secure().nextInt(1 << 32).toRadixString(16)}';

  final String controllerId;

  Socket? _socket;
  StreamSubscription<String>? _lineSub;
  final _events = StreamController<BridgeClientEvent>.broadcast();
  BridgeClientStatus _status = BridgeClientStatus.disconnected;
  String? _lastError;

  BridgeClientStatus get status => _status;
  String? get lastError => _lastError;
  bool get isConnected => _status == BridgeClientStatus.connected;

  /// Status transitions for the UI.
  Stream<BridgeClientEvent> get events => _events.stream;

  /// Connects and authenticates. Throws on failure after emitting an error
  /// event; callers may also watch [events].
  Future<void> connect({
    required String host,
    required int port,
    required String token,
    String? name,
  }) async {
    if (_status == BridgeClientStatus.connecting || isConnected) return;
    _setStatus(BridgeClientStatus.connecting);
    _lastError = null;
    try {
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      _socket = socket;
      socket.setOption(SocketOption.tcpNoDelay, true);

      _lineSub = utf8.decoder
          .bind(socket)
          .transform(const LineSplitter())
          .listen(
            _handleLine,
            onError: (Object e) => _fail('Connection error: $e'),
            onDone: () {
              if (_status != BridgeClientStatus.disconnected) {
                _setStatus(BridgeClientStatus.disconnected);
              }
            },
            cancelOnError: false,
          );

      _send(
        BridgeMessage.hello(
          token: token,
          controllerId: controllerId,
          controllerName: name,
        ),
      );

      // Wait briefly for the welcome handshake.
      final welcomed = await _waitForWelcome(const Duration(seconds: 5));
      if (!welcomed) {
        throw BridgeClientException('Bridge did not accept the pairing token.');
      }
      _setStatus(BridgeClientStatus.connected);
    } on SocketException {
      const msg =
          'Cannot reach the computer — check the address is correct and '
          'both devices are on the same Wi-Fi network.';
      _fail(msg);
      throw BridgeClientException(msg);
    } on TimeoutException {
      const msg =
          'Timed out reaching the computer — it may be asleep or the '
          'bridge is not running.';
      _fail(msg);
      throw BridgeClientException(msg);
    } catch (e) {
      _fail(e.toString());
      rethrow;
    }
  }

  Completer<bool> _welcomeCompleter = Completer<bool>();

  Future<bool> _waitForWelcome(Duration timeout) {
    if (_welcomeCompleter.isCompleted) {
      _welcomeCompleter = Completer<bool>();
    }
    return _welcomeCompleter.future.timeout(timeout, onTimeout: () => false);
  }

  void _handleLine(String line) {
    final message = BridgeMessage.decode(line);
    if (message == null) return;
    switch (message.type) {
      case BridgeMessageType.welcome:
        if (!_welcomeCompleter.isCompleted) {
          _welcomeCompleter.complete(true);
        }
      case BridgeMessageType.error:
        _lastError = message.message;
        _events.add(
          BridgeClientEvent(BridgeClientStatus.error, message.message),
        );
        if (_status == BridgeClientStatus.connecting) {
          _welcomeCompleter.complete(false);
        } else {
          unawaited(disconnect());
        }
      case BridgeMessageType.pong:
      case BridgeMessageType.unknown:
        break;
      default:
        break;
    }
  }

  void sendCc({
    required int channel,
    required int controller,
    required int value,
  }) {
    if (!isConnected) return;
    _send(
      BridgeMessage.cc(channel: channel, controller: controller, value: value),
    );
  }

  void sendNoteOn({
    required int channel,
    required int note,
    required int velocity,
  }) {
    if (!isConnected) return;
    _send(
      BridgeMessage.note(
        on: true,
        channel: channel,
        note: note,
        velocity: velocity,
      ),
    );
  }

  void sendNoteOff({
    required int channel,
    required int note,
    int velocity = 0,
  }) {
    if (!isConnected) return;
    _send(
      BridgeMessage.note(
        on: false,
        channel: channel,
        note: note,
        velocity: velocity,
      ),
    );
  }

  void sendPing() {
    if (!isConnected) return;
    _send(BridgeMessage.ping());
  }

  void _send(BridgeMessage message) {
    try {
      _socket?.write('${message.encode()}\n');
    } catch (_) {
      _fail('Send failed.');
    }
  }

  Future<void> disconnect() async {
    if (isConnected) {
      try {
        _send(BridgeMessage.bye());
      } catch (_) {}
    }
    await _teardown();
    _setStatus(BridgeClientStatus.disconnected);
  }

  Future<void> _teardown() async {
    await _lineSub?.cancel();
    _lineSub = null;
    _socket?.destroy();
    _socket = null;
  }

  void _fail(String message) {
    _lastError = message;
    _events.add(BridgeClientEvent(BridgeClientStatus.error, message));
    unawaited(_teardown());
    _setStatus(BridgeClientStatus.error);
  }

  void _setStatus(BridgeClientStatus status) {
    _status = status;
    _events.add(BridgeClientEvent(status));
  }

  /// Releases resources permanently.
  Future<void> dispose() async {
    await disconnect();
    await _events.close();
  }
}

class BridgeClientException implements Exception {
  BridgeClientException(this.message);
  final String message;
  @override
  String toString() => message;
}
