import 'package:flutter_test/flutter_test.dart';
import 'package:midiflow/infrastructure/midi/network/bridge_protocol.dart';

void main() {
  group('BridgeMessage encode/decode', () {
    test('cc round-trips', () {
      final msg = BridgeMessage.cc(channel: 1, controller: 7, value: 100);
      final decoded = BridgeMessage.decode(msg.encode());
      expect(decoded, isNotNull);
      expect(decoded!.type, BridgeMessageType.cc);
      expect(decoded.channel, 1);
      expect(decoded.controller, 7);
      expect(decoded.value, 100);
    });

    test('hello round-trips with token', () {
      final msg = BridgeMessage.hello(
        token: 'abc-123',
        controllerId: 'ctl-1',
        controllerName: 'Phone',
      );
      final decoded = BridgeMessage.decode(msg.encode());
      expect(decoded!.type, BridgeMessageType.hello);
      expect(decoded.token, 'abc-123');
      expect(decoded.controllerId, 'ctl-1');
      expect(decoded.controllerName, 'Phone');
      expect(decoded.version, bridgeProtocolVersion);
    });

    test('note on/off round-trip', () {
      final on = BridgeMessage.decode(
        BridgeMessage.note(
          on: true,
          channel: 3,
          note: 60,
          velocity: 100,
        ).encode(),
      )!;
      expect(on.type, BridgeMessageType.noteOn);
      expect(on.note, 60);
      expect(on.velocity, 100);

      final off = BridgeMessage.decode(
        BridgeMessage.note(
          on: false,
          channel: 3,
          note: 60,
          velocity: 0,
        ).encode(),
      )!;
      expect(off.type, BridgeMessageType.noteOff);
      expect(off.noteOn, isFalse);
    });

    test('ping/pong/error/bye decode', () {
      expect(
        BridgeMessage.decode('{"t":"ping"}')!.type,
        BridgeMessageType.ping,
      );
      expect(
        BridgeMessage.decode('{"t":"pong"}')!.type,
        BridgeMessageType.pong,
      );
      expect(BridgeMessage.decode('{"t":"bye"}')!.type, BridgeMessageType.bye);
      final err = BridgeMessage.decode('{"t":"error","msg":"nope"}')!;
      expect(err.type, BridgeMessageType.error);
      expect(err.message, 'nope');
    });

    test('malformed input returns null', () {
      expect(BridgeMessage.decode('not json'), isNull);
      expect(BridgeMessage.decode(''), isNull);
      expect(BridgeMessage.decode('{"t":"cc"}'), isNull); // missing fields
      expect(BridgeMessage.decode('[1,2,3]'), isNull);
    });

    test('unknown type yields unknown message', () {
      expect(
        BridgeMessage.decode('{"t":"warp"}')!.type,
        BridgeMessageType.unknown,
      );
    });

    test('future protocol version yields error', () {
      final msg = BridgeMessage.decode(
        '{"v":99,"t":"cc","ch":1,"cc":7,"val":100}',
      )!;
      expect(msg.type, BridgeMessageType.error);
      expect(msg.message, contains('Unsupported protocol version'));
    });
  });
}
