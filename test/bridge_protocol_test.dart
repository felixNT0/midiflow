import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:midiflow/infrastructure/midi/network/bridge_protocol.dart';

void main() {
  group('BridgeProtocol', () {
    test('encodes CC message', () {
      final message = BridgeMessage.cc(
        channel: 1,
        controller: 7,
        value: 100,
      );

      final encoded = message.encode();
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['t'], 'cc');
      expect(decoded['ch'], 1);
      expect(decoded['cc'], 7);
      expect(decoded['val'], 100);
    });

    test('encodes Note On message', () {
      final message = BridgeMessage.note(
        on: true,
        channel: 1,
        note: 60,
        velocity: 100,
      );

      final encoded = message.encode();
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['t'], 'noteOn');
      expect(decoded['ch'], 1);
      expect(decoded['n'], 60);
      expect(decoded['vel'], 100);
    });

    test('encodes Note Off message', () {
      final message = BridgeMessage.note(
        on: false,
        channel: 1,
        note: 60,
        velocity: 0,
      );

      final encoded = message.encode();
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['t'], 'noteOff');
      expect(decoded['ch'], 1);
      expect(decoded['n'], 60);
      expect(decoded['vel'], 0);
    });

    test('decodes CC message', () {
      final json = '{"v":1,"t":"cc","ch":1,"cc":7,"val":100}';
      final message = BridgeMessage.decode(json);

      expect(message, isNotNull);
      expect(message!.type, BridgeMessageType.cc);
      expect(message.channel, 1);
      expect(message.controller, 7);
      expect(message.value, 100);
    });

    test('decodes Note On message', () {
      final json = '{"v":1,"t":"noteOn","ch":1,"n":60,"vel":100}';
      final message = BridgeMessage.decode(json);

      expect(message, isNotNull);
      expect(message!.type, BridgeMessageType.noteOn);
      expect(message.channel, 1);
      expect(message.note, 60);
      expect(message.velocity, 100);
    });

    test('handles hello message', () {
      final message = BridgeMessage.hello(
        token: 'test-token',
        controllerId: 'phone-1',
        controllerName: 'My Phone',
      );

      final encoded = message.encode();
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['t'], 'hello');
      expect(decoded['token'], 'test-token');
      expect(decoded['id'], 'phone-1');
      expect(decoded['name'], 'My Phone');
    });

    test('handles welcome message', () {
      final message = BridgeMessage.welcome(assignedId: 'server-1');

      final encoded = message.encode();
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['t'], 'welcome');
      expect(decoded['id'], 'server-1');
    });

    test('handles ping/pong', () {
      final ping = BridgeMessage.ping();
      final pong = BridgeMessage.pong();

      expect(jsonDecode(ping.encode())['t'], 'ping');
      expect(jsonDecode(pong.encode())['t'], 'pong');
    });

    test('handles error message', () {
      final message = BridgeMessage.error('Test error');

      final encoded = message.encode();
      final decoded = jsonDecode(encoded) as Map<String, dynamic>;

      expect(decoded['t'], 'error');
      expect(decoded['msg'], 'Test error');
    });
  });
}
