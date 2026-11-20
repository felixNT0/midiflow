import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../infrastructure/midi/network/bridge_client.dart';
import '../../infrastructure/midi/network/bridge_protocol.dart';
import '../../infrastructure/midi/network/bridge_server.dart';
import 'midi_provider.dart';

/// Android foreground-service channel used to keep the bridge socket alive
/// while the app is backgrounded. Missing on desktop platforms — calls are
/// wrapped in try/catch.
const _bridgeServiceChannel = MethodChannel('midiflow/bridge');

Future<void> _setBridgeServiceRunning(bool running) async {
  try {
    await _bridgeServiceChannel.invokeMethod(
      running ? 'startService' : 'stopService',
    );
  } catch (_) {
    // Not an Android build or service unavailable — ignore.
  }
}

const _kHostKey = 'bridge_host';
const _kPortKey = 'bridge_port';
const _kTokenKey = 'bridge_token';
const _kServerTokenKey = 'bridge_server_token';

String generatePairingToken() {
  final random = Random.secure();
  return List.generate(
    3,
    (_) => random.nextInt(1 << 32).toRadixString(16).padLeft(8, '0'),
  ).join('-');
}

/// Non-loopback IPv4 addresses of this machine, for display on the bridge UI.
Future<List<String>> localLanAddresses() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    return [
      for (final i in interfaces)
        for (final a in i.addresses)
          if (!a.isLoopback) a.address,
    ];
  } catch (_) {
    return const [];
  }
}

// ---------------------------------------------------------------------------
// Desktop bridge server
// ---------------------------------------------------------------------------

class BridgeServerState {
  const BridgeServerState({
    this.running = false,
    this.starting = false,
    this.stopping = false,
    this.token,
    this.port = bridgeDefaultPort,
    this.endpointName,
    this.clients = const [],
    this.lanAddresses = const [],
    this.error,
  });

  final bool running;
  final bool starting;
  final bool stopping;
  final String? token;
  final int port;
  final String? endpointName;
  final List<BridgeClientInfo> clients;
  final List<String> lanAddresses;
  final String? error;

  BridgeServerState copyWith({
    bool? running,
    bool? starting,
    bool? stopping,
    String? token,
    int? port,
    String? endpointName,
    List<BridgeClientInfo>? clients,
    List<String>? lanAddresses,
    String? error,
    bool clearError = false,
  }) {
    return BridgeServerState(
      running: running ?? this.running,
      starting: starting ?? this.starting,
      stopping: stopping ?? this.stopping,
      token: token ?? this.token,
      port: port ?? this.port,
      endpointName: endpointName ?? this.endpointName,
      clients: clients ?? this.clients,
      lanAddresses: lanAddresses ?? this.lanAddresses,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class BridgeServerController extends Notifier<BridgeServerState> {
  BridgeServer? _server;

  @override
  BridgeServerState build() {
    ref.onDispose(_dispose);
    // On desktop the bridge is the whole point of the app — start it
    // automatically so controllers reconnect without manual setup.
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    final isTest = Platform.environment['FLUTTER_TEST'] == 'true';
    if (isDesktop && !isTest) {
      // Deferred: state is not readable until build() returns.
      unawaited(Future(() => start()));
    }
    return const BridgeServerState();
  }

  /// Loads the persisted pairing token, generating and saving one on first
  /// run. A stable token means paired phones keep working across app
  /// restarts and reboots.
  Future<String> _loadOrCreateToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_kServerTokenKey);
      if (saved != null && saved.isNotEmpty) return saved;
      final token = generatePairingToken();
      await prefs.setString(_kServerTokenKey, token);
      return token;
    } catch (_) {
      return generatePairingToken();
    }
  }

  Future<void> start() async {
    if (state.running || state.starting) return;
    state = state.copyWith(starting: true, clearError: true);
    try {
      final midiService = ref.read(midiServiceProvider);
      final token = await _loadOrCreateToken();
      final server = BridgeServer(
        midiService: midiService,
        onClientChanged: _refreshClients,
      );
      await server.start(token: token);
      _server = server;
      final addresses = await localLanAddresses();
      state = state.copyWith(
        running: true,
        starting: false,
        token: token,
        endpointName: server.endpoint?.name,
        lanAddresses: addresses,
        clients: server.clients,
      );
    } catch (e) {
      state = state.copyWith(
        starting: false,
        error: 'Failed to start bridge: $e',
      );
    }
  }

  Future<void> stop() async {
    if (!state.running || state.stopping) return;
    state = state.copyWith(stopping: true, clearError: true);
    try {
      await _server?.stop();
      _server = null;
      state = state.copyWith(
        running: false,
        stopping: false,
        token: null,
        endpointName: null,
        clients: const [],
      );
    } catch (e) {
      state = state.copyWith(stopping: false, error: e.toString());
    }
  }

  void _refreshClients() {
    final server = _server;
    if (server == null) return;
    state = state.copyWith(clients: server.clients);
  }

  Future<void> _dispose() async {
    await _server?.stop();
    _server = null;
  }
}

final bridgeServerProvider =
    NotifierProvider<BridgeServerController, BridgeServerState>(
      BridgeServerController.new,
    );

// ---------------------------------------------------------------------------
// Mobile bridge client
// ---------------------------------------------------------------------------

class BridgeClientState {
  const BridgeClientState({
    this.status = BridgeClientStatus.disconnected,
    this.host = '',
    this.port = bridgeDefaultPort,
    this.token = '',
    this.lastError,
  });

  final BridgeClientStatus status;
  final String host;
  final int port;
  final String token;
  final String? lastError;

  bool get isConnected => status == BridgeClientStatus.connected;

  BridgeClientState copyWith({
    BridgeClientStatus? status,
    String? host,
    int? port,
    String? token,
    String? lastError,
    bool clearError = false,
  }) {
    return BridgeClientState(
      status: status ?? this.status,
      host: host ?? this.host,
      port: port ?? this.port,
      token: token ?? this.token,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }
}

class BridgeClientController extends Notifier<BridgeClientState> {
  BridgeClient? _client;
  StreamSubscription<BridgeClientEvent>? _eventSub;
  Timer? _reconnectTimer;
  Timer? _keepAliveTimer;
  int _reconnectAttempts = 0;
  bool _manualDisconnect = false;

  @override
  BridgeClientState build() {
    ref.onDispose(_dispose);
    unawaited(_restoreAndAutoConnect());
    return const BridgeClientState();
  }

  /// Loads saved bridge credentials and reconnects automatically so the
  /// app resumes controlling FL Studio without manual setup.
  Future<void> _restoreAndAutoConnect() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final host = prefs.getString(_kHostKey) ?? '';
      final token = prefs.getString(_kTokenKey) ?? '';
      final port = prefs.getInt(_kPortKey) ?? bridgeDefaultPort;
      if (host.isNotEmpty && token.isNotEmpty) {
        state = state.copyWith(host: host, port: port, token: token);
        await connect();
      }
    } catch (_) {
      // SharedPreferences unavailable — stay disconnected.
    }
  }

  Future<void> _saveCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kHostKey, state.host);
      await prefs.setInt(_kPortKey, state.port);
      await prefs.setString(_kTokenKey, state.token);
    } catch (_) {}
  }

  void setHost(String host) {
    state = state.copyWith(host: host.trim(), clearError: true);
    unawaited(_saveCredentials());
  }

  void setPort(int port) {
    if (port < 1 || port > 65535) return;
    state = state.copyWith(port: port, clearError: true);
    unawaited(_saveCredentials());
  }

  void setToken(String token) {
    state = state.copyWith(token: token.trim(), clearError: true);
    unawaited(_saveCredentials());
  }

  Future<void> connect() async {
    if (state.status == BridgeClientStatus.connecting || state.isConnected) {
      return;
    }
    if (state.host.isEmpty || state.token.isEmpty) {
      state = state.copyWith(
        status: BridgeClientStatus.error,
        lastError: 'Enter the bridge host and pairing token.',
      );
      return;
    }
    _manualDisconnect = false;
    state = state.copyWith(
      status: BridgeClientStatus.connecting,
      clearError: true,
    );
    try {
      _client ??= BridgeClient();
      await _client!.connect(
        host: state.host,
        port: state.port,
        token: state.token,
      );
      await _eventSub?.cancel();
      _eventSub = _client!.events.listen(_onEvent);
      _reconnectAttempts = 0;
      _startKeepAlive();
      unawaited(_setBridgeServiceRunning(true));
      unawaited(_saveCredentials());
      state = state.copyWith(status: BridgeClientStatus.connected);
    } catch (e) {
      state = state.copyWith(
        status: BridgeClientStatus.error,
        lastError: e.toString(),
      );
      _scheduleReconnect();
    }
  }

  Future<void> disconnect() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _keepAliveTimer?.cancel();
    await _client?.disconnect();
    unawaited(_setBridgeServiceRunning(false));
    state = state.copyWith(status: BridgeClientStatus.disconnected);
  }

  void _onEvent(BridgeClientEvent event) {
    switch (event.status) {
      case BridgeClientStatus.disconnected:
        _keepAliveTimer?.cancel();
        state = state.copyWith(status: BridgeClientStatus.disconnected);
        _scheduleReconnect();
      case BridgeClientStatus.error:
        _keepAliveTimer?.cancel();
        state = state.copyWith(
          status: BridgeClientStatus.error,
          lastError: event.message,
        );
        _scheduleReconnect();
      case BridgeClientStatus.connecting:
      case BridgeClientStatus.connected:
        break;
    }
  }

  /// Retries the connection with a capped backoff until the user manually
  /// disconnects or credentials are cleared.
  void _scheduleReconnect() {
    if (_manualDisconnect) return;
    if (state.host.isEmpty || state.token.isEmpty) return;
    if (state.status == BridgeClientStatus.connecting) return;
    _reconnectTimer?.cancel();
    final delaySeconds = min(5 * (_reconnectAttempts + 1), 30);
    _reconnectAttempts++;
    _reconnectTimer = Timer(
      Duration(seconds: delaySeconds),
      () => unawaited(connect()),
    );
  }

  /// Periodic ping keeps the socket exercised and lets the server see the
  /// client as alive while the phone screen is off.
  void _startKeepAlive() {
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _client?.sendPing();
    });
  }

  /// Sends a CC through the bridge. No-op unless connected.
  void sendCc({
    required int channel,
    required int controller,
    required int value,
  }) {
    if (!state.isConnected) return;
    _client?.sendCc(channel: channel, controller: controller, value: value);
  }

  /// Sends a Note On through the bridge. No-op unless connected.
  void sendNoteOn({
    required int channel,
    required int note,
    int velocity = 100,
  }) {
    if (!state.isConnected) return;
    _client?.sendNoteOn(channel: channel, note: note, velocity: velocity);
  }

  /// Sends a Note Off through the bridge. No-op unless connected.
  void sendNoteOff({required int channel, required int note}) {
    if (!state.isConnected) return;
    _client?.sendNoteOff(channel: channel, note: note);
  }

  Future<void> _dispose() async {
    _manualDisconnect = true;
    _reconnectTimer?.cancel();
    _keepAliveTimer?.cancel();
    await _eventSub?.cancel();
    await _client?.dispose();
    _client = null;
    unawaited(_setBridgeServiceRunning(false));
  }
}

final bridgeClientProvider =
    NotifierProvider<BridgeClientController, BridgeClientState>(
      BridgeClientController.new,
    );
