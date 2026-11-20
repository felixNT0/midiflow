import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/midi/bridge_provider.dart';
import '../../application/midi/midi_provider.dart';
import '../../application/settings/theme_mode_provider.dart';
import '../../infrastructure/midi/midi_service.dart';
import '../../infrastructure/midi/network/bridge_client.dart';
import '../../infrastructure/midi/network/bridge_protocol.dart';
import '../bridge/bridge_screen.dart';
import '../diagnostics/midi_diagnostics_screen.dart';

/// App settings: connection shortcuts and engine status. Detailed MIDI
/// controls live on the diagnostics screen.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final midi = ref.watch(midiControllerProvider);
    final devices = midi.devices;
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment(
                          value: ThemeMode.system,
                          icon: Icon(Icons.brightness_auto),
                          label: Text('System'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode),
                          label: Text('Light'),
                        ),
                        ButtonSegment(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode),
                          label: Text('Dark'),
                        ),
                      ],
                      selected: {themeMode},
                      onSelectionChanged: (selection) => ref
                          .read(themeModeProvider.notifier)
                          .setMode(selection.first),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.memory),
                  title: const Text('MIDI engine'),
                  subtitle: Text(_statusLabel(midi.status)),
                  trailing: midi.busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : null,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.devices),
                  title: const Text('Devices'),
                  subtitle: Text('${devices.length} discovered'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bluetooth),
                  title: const Text('BLE MIDI'),
                  subtitle: const Text('Enabled (flutter_midi_command_ble)'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_isDesktop) const _BridgeServerCard(),
          const SizedBox(height: 16),
          const _BridgeClientCard(),
          const SizedBox(height: 16),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.monitor_heart_outlined),
                  title: const Text('MIDI diagnostics'),
                  subtitle: const Text(
                    'Device list, ports, CC send test and incoming message log',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const MidiDiagnosticsScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                const _KontaktSetupCard(),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Transport, channel defaults, reconnect, smoothing and haptics '
                'controls will be configurable here in later milestones.',
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _isDesktop =>
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.linux;

  String _statusLabel(MidiEngineStatus status) => switch (status) {
    MidiEngineStatus.uninitialized => 'Uninitialized',
    MidiEngineStatus.initializing => 'Initializing…',
    MidiEngineStatus.ready => 'Ready',
    MidiEngineStatus.error => 'Error',
  };
}

/// Desktop-only card that opens the bridge server panel.
class _BridgeServerCard extends StatelessWidget {
  const _BridgeServerCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.cable),
        title: const Text('Desktop bridge'),
        subtitle: const Text(
          'Share this computer\'s MIDI endpoint with phones/tablets on '
          'your network',
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute<void>(builder: (_) => const BridgeScreen())),
      ),
    );
  }
}

/// Connects this device to a running desktop bridge.
class _BridgeClientCard extends ConsumerStatefulWidget {
  const _BridgeClientCard();

  @override
  ConsumerState<_BridgeClientCard> createState() => _BridgeClientCardState();
}

class _BridgeClientCardState extends ConsumerState<_BridgeClientCard> {
  final _host = TextEditingController();
  final _port = TextEditingController(text: '$bridgeDefaultPort');
  final _token = TextEditingController();

  @override
  void dispose() {
    _host.dispose();
    _port.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bridgeClientProvider);
    final ctrl = ref.read(bridgeClientProvider.notifier);
    final busy = state.status == BridgeClientStatus.connecting;

    // Populate the fields once persisted credentials finish loading so a
    // returning user sees what's saved instead of blank boxes.
    ref.listen(bridgeClientProvider, (prev, next) {
      if (_host.text != next.host) _host.text = next.host;
      if (_token.text != next.token) _token.text = next.token;
      final portText = '${next.port}';
      if (_port.text != portText) _port.text = portText;
    });

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connect to computer',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              'Send controls to a desktop running the MIDIFlow bridge. '
              'Enter the address and token shown there.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _host,
              decoration: const InputDecoration(
                labelText: 'Computer address (IP or hostname)',
                hintText: '192.168.1.20',
              ),
              keyboardType: TextInputType.url,
              onChanged: ctrl.setHost,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  flex: 1,
                  child: TextField(
                    controller: _port,
                    decoration: const InputDecoration(labelText: 'Port'),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => ctrl.setPort(int.tryParse(v) ?? 0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _token,
                    decoration: const InputDecoration(
                      labelText: 'Pairing token',
                    ),
                    onChanged: ctrl.setToken,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: Icon(state.isConnected ? Icons.link_off : Icons.link),
                label: Text(
                  busy
                      ? 'Connecting…'
                      : state.isConnected
                      ? 'Disconnect'
                      : 'Connect',
                ),
                onPressed: busy
                    ? null
                    : (state.isConnected ? ctrl.disconnect : ctrl.connect),
              ),
            ),
            if (state.lastError != null) ...[
              const SizedBox(height: 8),
              Text(
                state.lastError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (state.isConnected)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Connected — Play screen controls now go to the bridge.',
                  style: TextStyle(color: Colors.green.shade300),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Contact setup instructions for FL Studio + Kontakt integration.
class _KontaktSetupCard extends StatefulWidget {
  const _KontaktSetupCard();

  @override
  State<_KontaktSetupCard> createState() => _KontaktSetupCardState();
}

class _KontaktSetupCardState extends State<_KontaktSetupCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.piano),
      title: const Text('Kontakt Layer Setup'),
      subtitle: const Text('How to control individual Kontakt layers'),
      trailing: Icon(
        _expanded ? Icons.expand_less : Icons.expand_more,
        color: Theme.of(context).colorScheme.primary,
      ),
      onExpansionChanged: (expanded) {
        setState(() => _expanded = expanded);
      },
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To assign MIDIFlow controls to Kontakt parameters (layer volumes, pads, drums, effects):',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              _buildStep(context, '1', 'Open Kontakt and go to the Automation tab'),
              _buildStep(context, '2', 'Click "Quick Controls" to edit'),
              _buildStep(context, '3', 'Assign each layer volume to Quick Controls 1-8'),
              _buildStep(context, '4', 'Right-click each Quick Control → "Learn MIDI CC"'),
              _buildStep(context, '5', 'Move the matching MIDIFlow control to learn its CC'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.3),
                  ),
                ),
                child: Text(
                  'FL Studio: set the plugin wrapper MIDI Input port to 10 first. '
                  'CC map (MIDI channel 1, or selected Part channel): layer volumes '
                  'CC20-27, layer on/off CC28-35, pads CC36-47, drums CC48-63, '
                  'effects CC96-107. Logic Pro needs no port setup.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStep(BuildContext context, String number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary
                  .withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
