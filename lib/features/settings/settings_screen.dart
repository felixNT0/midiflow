import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/midi/bridge_provider.dart';
import '../../application/midi/controls_provider.dart';
import '../../application/midi/midi_provider.dart';
import '../../application/settings/theme_mode_provider.dart';
import '../../domain/midi/control_bank.dart';
import '../../domain/midi/midi_control.dart';
import '../../infrastructure/midi/midi_service.dart';
import '../../infrastructure/midi/network/bridge_client.dart';
import '../../infrastructure/midi/network/bridge_protocol.dart';
import '../assign/assign_screen.dart';
import '../ble/ble_midi_screen.dart';
import '../bridge/bridge_screen.dart';
import '../diagnostics/midi_activity_monitor.dart';
import '../diagnostics/midi_diagnostics_screen.dart';
import '../guide/app_guide_screen.dart';
import '../profiles/profiles_screen.dart';
import '../sequencer/sequence_recorder.dart';

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
                  subtitle: const Text('Connect via Bluetooth LE'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const BleMidiScreen(),
                    ),
                  ),
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
          const SizedBox(height: 16),
          _NavigationCard(
            icon: Icons.tune,
            title: 'Assign Controls',
            subtitle: 'Edit MIDI mappings, CC numbers, and channels for each control',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AssignScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _NavigationCard(
            icon: Icons.folder_copy_outlined,
            title: 'Profiles',
            subtitle: 'Save and load different control layouts for different songs/venues',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ProfilesScreen()),
            ),
          ),
          const SizedBox(height: 8),
          _NavigationCard(
            icon: Icons.help_outline,
            title: 'App Guide',
            subtitle: 'Learn how each screen works and how to use MIDIFlow',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AppGuideScreen()),
            ),
          ),
          const SizedBox(height: 16),
          const _SetupGuidesCard(),
          const SizedBox(height: 16),
          const _ControlLabelsCard(),
          const SizedBox(height: 16),
          const MidiActivityMonitor(),
          const SizedBox(height: 16),
          const SequenceRecorder(),
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

/// Setup guides for connecting the phone/tablet to the laptop and DAW-specific
/// instructions. Available on all platforms (mobile and desktop).
class _SetupGuidesCard extends StatelessWidget {
  const _SetupGuidesCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: const [
          _GuideTile(
            title: '1 · Connect phone to computer',
            steps: [
              'Keep the Desktop Bridge screen open on the laptop — the bridge '
                  'starts automatically and shows a pairing token and '
                  'network address.',
              'On the phone, open Settings → Connect to computer.',
              'Enter the laptop address and token shown on the laptop, then '
                  'tap Connect. Both devices must be on the same Wi-Fi '
                  'network.',
              'Important: if you switch Wi-Fi networks (home, church, '
                  'hotspot), the laptop IP address will change — always '
                  'check the Desktop Bridge screen and update the address '
                  'on the phone before connecting.',
              'Windows laptops: install loopMIDI or Windows MIDI '
                  'Services first so a virtual MIDI port can be created.',
            ],
          ),
          Divider(height: 1),
          _GuideTile(
            title: '2 · FL Studio setup',
            steps: [
              'Install the controller script: copy device_midiflow.py '
                  'into FL Studio\'s user data folder at '
                  'Settings/Hardware/MIDIFlow/ (create the folder if '
                  'missing), then restart FL Studio.',
              'Options → MIDI Settings → Input = "MIDIFlow Bridge", '
                  'Controller type = "MIDIFlow".',
              'Transport, mixer and channel-rack controls work '
                  'automatically through the script — nothing else to '
                  'configure for those.',
              'For Kontakt/VST instruments: open the plugin wrapper '
                  'settings → MIDI tab → set Input port = 10. This lets '
                  'the script deliver instrument CCs as real MIDI.',
              'In Kontakt, assign controls with right-click → Learn '
                  'MIDI CC: layer faders CC20-27, layer on/off CC28-35, '
                  'pads CC36-47, drums CC48-63, FX CC96-107 (all on '
                  'MIDI channel 1, or the Part channel you select).',
            ],
          ),
          Divider(height: 1),
          _GuideTile(
            title: '3 · Logic Pro setup',
            steps: [
              'No script needed — "MIDIFlow Bridge" appears as a normal '
                  'MIDI input automatically.',
              'Logic Pro → Settings → MIDI → enable "MIDIFlow Bridge" '
                  'as an input device.',
              'Create a Software Instrument track with Kontakt — it '
                  'receives MIDI from the enabled input directly.',
              'Kontakt Learn works with no extra setup: right-click a '
                  'control → Learn MIDI CC, then move the matching '
                  'MIDIFlow control.',
              'Transport and mixer controls are not scriptable in '
                  'Logic — assign them once in Logic\'s Controller '
                  'Assignments (Environment → Controller Environment, '
                  'learn mode) using the same CCs the FL Studio script '
                  'uses: ch16 CC30 play/pause, CC31 stop, CC32 record, '
                  'CC14 master volume.',
            ],
          ),
        ],
      ),
    );
  }
}

class _GuideTile extends StatelessWidget {
  const _GuideTile({required this.title, required this.steps});

  final String title;
  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      children: [
        for (var i = 0; i < steps.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  child: Text(
                    '${i + 1}.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                Expanded(
                  child: Text(
                    steps[i],
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Card for renaming control labels (layer faders, pads, etc.) after assignment.
class _ControlLabelsCard extends ConsumerWidget {
  const _ControlLabelsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(controlsProvider);
    final controlsCtrl = ref.read(controlsProvider.notifier);

    // Group controls by bank for easier navigation
    final banks = state.banks;

    return Card(
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        title: const Text(
          'Rename Controls',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: const Text(
          'Tap a control to rename it (e.g., Layer 1 → Piano, Pad C → Pad 1)',
        ),
        children: [
          for (final bank in banks)
            _BankLabelsSection(
              bank: bank,
              onRename: (controlId, newLabel) =>
                  controlsCtrl.updateControlLabel(controlId, newLabel),
            ),
        ],
      ),
    );
  }
}

class _BankLabelsSection extends StatelessWidget {
  const _BankLabelsSection({
    required this.bank,
    required this.onRename,
  });

  final ControlBank bank;
  final void Function(String controlId, String newLabel) onRename;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Text(
            bank.name,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ),
        for (final control in bank.controls)
          _ControlLabelTile(
            control: control,
            onRename: (newLabel) => onRename(control.id, newLabel),
          ),
      ],
    );
  }
}

class _ControlLabelTile extends StatelessWidget {
  const _ControlLabelTile({
    required this.control,
    required this.onRename,
  });

  final MidiControl control;
  final void Function(String newLabel) onRename;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(control.label),
      subtitle: Text(
        '${control.type.name} · ch${control.mapping.channel} CC${control.mapping.controller}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit, size: 18),
        onPressed: () => _showRenameDialog(context),
      ),
    );
  }

  void _showRenameDialog(BuildContext context) {
    final controller = TextEditingController(text: control.label);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Control'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'New name',
            hintText: 'e.g., Piano, Pad 1, Reverb',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              final newLabel = controller.text.trim();
              if (newLabel.isNotEmpty) {
                onRename(newLabel);
              }
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

/// Navigation card for accessing secondary screens (Assign, Profiles).
class _NavigationCard extends StatelessWidget {
  const _NavigationCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
