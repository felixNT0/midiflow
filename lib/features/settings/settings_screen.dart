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
import '../usb/usb_midi_screen.dart';

/// App settings with tabbed interface for better organization.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final midi = ref.watch(midiControllerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          bottom: const TabBar(
            tabs: [
              Tab(icon: Icon(Icons.settings), text: 'General'),
              Tab(icon: Icon(Icons.cable), text: 'Connections'),
              Tab(icon: Icon(Icons.tune), text: 'Controls'),
              Tab(icon: Icon(Icons.build), text: 'Tools'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _GeneralTab(state: midi, themeMode: themeMode),
            _ConnectionsTab(state: midi),
            _ControlsTab(),
            _ToolsTab(),
          ],
        ),
      ),
    );
  }
}

/// General settings tab: theme, MIDI engine status.
class _GeneralTab extends ConsumerWidget {
  const _GeneralTab({required this.state, required this.themeMode});

  final MidiState state;
  final ThemeMode themeMode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
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
                subtitle: Text(_statusLabel(state.status)),
                trailing: state.busy
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
                subtitle: Text('${state.devices.length} discovered'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _SetupGuidesCard(),
      ],
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

/// Connections tab: Wi-Fi bridge, BLE MIDI, USB MIDI.
class _ConnectionsTab extends ConsumerWidget {
  const _ConnectionsTab({required this.state});

  final MidiState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDesktop = defaultTargetPlatform == TargetPlatform.macOS ||
        defaultTargetPlatform == TargetPlatform.windows ||
        defaultTargetPlatform == TargetPlatform.linux;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (isDesktop) const _BridgeServerCard(),
        const SizedBox(height: 16),
        const _BridgeClientCard(),
        const SizedBox(height: 16),
        _NavigationCard(
          icon: Icons.bluetooth,
          title: 'BLE MIDI',
          subtitle: 'Connect via Bluetooth LE',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const BleMidiScreen(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _NavigationCard(
          icon: Icons.usb,
          title: 'USB MIDI',
          subtitle: 'Connect via USB cable',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const UsbMidiScreen(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        _NavigationCard(
          icon: Icons.monitor_heart_outlined,
          title: 'MIDI Diagnostics',
          subtitle: 'Device list, ports, CC send test and incoming message log',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const MidiDiagnosticsScreen(),
            ),
          ),
        ),
      ],
    );
  }
}

/// Controls tab: Assign, Profiles, Control Labels.
class _ControlsTab extends ConsumerWidget {
  const _ControlsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
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
        const SizedBox(height: 16),
        const _ControlLabelsCard(),
      ],
    );
  }
}

/// Tools tab: Sequence Recorder, MIDI Activity Monitor, App Guide.
class _ToolsTab extends ConsumerWidget {
  const _ToolsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SequenceRecorder(),
        const SizedBox(height: 16),
        const MidiActivityMonitor(),
        const SizedBox(height: 16),
        _NavigationCard(
          icon: Icons.help_outline,
          title: 'App Guide',
          subtitle: 'Learn how each screen works and how to use MIDIFlow',
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const AppGuideScreen()),
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
    );
  }
}

/// Navigation card for Settings screens.
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
            Text('Connect to computer', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _host,
              decoration: const InputDecoration(
                labelText: 'Host (IP or hostname)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.url,
              onChanged: ctrl.setHost,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _port,
                    decoration: const InputDecoration(
                      labelText: 'Port',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    onChanged: (v) => ctrl.setPort(int.tryParse(v) ?? bridgeDefaultPort),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _token,
                    decoration: const InputDecoration(
                      labelText: 'Pairing token',
                      border: OutlineInputBorder(),
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
                icon: Icon(state.status == BridgeClientStatus.connected
                    ? Icons.link_off
                    : Icons.link),
                label: Text(
                  state.status == BridgeClientStatus.connected
                      ? 'Disconnect'
                      : busy
                          ? 'Connecting…'
                          : 'Connect',
                ),
                onPressed: busy || state.host.isEmpty
                    ? null
                    : () {
                        if (state.status == BridgeClientStatus.connected) {
                          ctrl.disconnect();
                        } else {
                          ctrl.connect();
                        }
                      },
              ),
            ),
            if (state.lastError != null) ...[
              const SizedBox(height: 8),
              Text(
                state.lastError!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 8),
            Text(
              'On the computer: Settings → Desktop bridge → start the server, '
              'then enter its IP, port and token here and tap Connect. Both '
              'devices must be on the same Wi-Fi network.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
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
      child: ExpansionTile(
        leading: const Icon(Icons.menu_book_outlined),
        title: const Text('Setup guides'),
        subtitle: const Text('FL Studio, Logic Pro & Kontakt'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _GuideSection(
                  title: 'Quick start (Wi-Fi bridge)',
                  lines: const [
                    '1. On the laptop, open MIDIFlow → Settings → Desktop bridge and start the server.',
                    '2. Note the shown IP address, port and token.',
                    '3. On the phone, Settings → Connect to computer, enter the same values and tap Connect.',
                    '4. In FL Studio, add a controller of type "MIDIFlow" (script in tools/flstudio).',
                    '5. On the phone Play tab, pick the channel part and move the controls.',
                  ],
                ),
                const SizedBox(height: 12),
                _GuideSection(
                  title: 'FL Studio (scriptable MIDI controller)',
                  lines: const [
                    '1. Copy tools/flstudio/device_midiflow.py into FL Studio’s Hardware MIDI settings folder',
                    '    macOS: ~/Documents/Image-Line/FL Studio/Settings/Hardware/',
                    '    Windows: Documents\\Image-Line\\FL Studio\\Settings\\Hardware\\',
                    '2. Restart FL Studio (or rescan controllers).',
                    '3. MIDI Settings → Controller type: "MIDIFlow".',
                    '4. Device: the "MIDIFlow Bridge" input.',
                    'Transport, mixer and channel rack controls are scriptable',
                    'and will be wired in later milestones.',
                  ],
                ),
                const SizedBox(height: 12),
                _GuideSection(
                  title: 'Logic Pro',
                  lines: const [
                    'Logic Pro → Settings → MIDI → enable "MIDIFlow Bridge" '
                    'as a MIDI input device.',
                    'Create a Software Instrument track and route it so Logic '
                    'receives MIDI from the enabled input directly.',
                    'Note: transport and mixer controls are not scriptable in '
                    'the same way as FL Studio; use them for instrument control.',
                  ],
                ),
                const SizedBox(height: 12),
                const _KontaktSetupCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Contact setup instructions for Kontakt instruments.
class _KontaktSetupCard extends StatelessWidget {
  const _KontaktSetupCard();

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      leading: const Icon(Icons.album_outlined),
      title: const Text('Kontakt setup'),
      subtitle: const Text('Layer volumes & pads'),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Each control sends a MIDI CC on channel 1 through the plugin '
                'MIDI port. In Kontakt, right-click a parameter → MIDI Learn, '
                'then move the corresponding control.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              _GuideSection(
                title: 'Layer volumes (CC20–27)',
                lines: const [
                  'Layer 1 → CC20, Layer 2 → CC21, … Layer 8 → CC27',
                  'Faders send continuous values; assign each to a Kontakt '
                  'layer volume.',
                ],
              ),
              const SizedBox(height: 8),
              _GuideSection(
                title: 'Layer on/off (CC28–35)',
                lines: const [
                  'Layer 1 On/Off → CC28, Layer 2 → CC29, … Layer 8 → CC35',
                  'Toggle buttons send 0/127; assign to Kontakt layer mute '
                  'buttons.',
                ],
              ),
              const SizedBox(height: 8),
              _GuideSection(
                title: 'Continuous pads (CC36–47)',
                lines: const [
                  'Pad 1 → CC36, Pad 2 → CC37, … Pad 12 → CC47',
                  'Tap a pad to send 127, release to send 0. Assign each pad '
                  'to a Kontakt parameter (drone, pad, effect, etc.).',
                ],
              ),
              const SizedBox(height: 8),
              _GuideSection(
                title: 'Pad volume (CC48)',
                lines: const [
                  'Pad Vol fader sends CC48. Assign to the Kontakt library\'s '
                  'pad volume control.',
                ],
              ),
              const SizedBox(height: 8),
              _GuideSection(
                title: 'Drums (CC48–63)',
                lines: const [
                  'Drum pads send CC48–CC63 on channel 1. Assign each pad to '
                  'a drum hit or one-shot in Kontakt.',
                ],
              ),
              const SizedBox(height: 8),
              _GuideSection(
                title: 'Effects (CC96–107)',
                lines: const [
                  'Effect knobs send CC96–CC107 on channel 1. Assign to '
                  'reverb, delay, filter, etc.',
                ],
              ),
              const SizedBox(height: 8),
              _GuideSection(
                title: 'Transport (channel 16)',
                lines: const [
                  'Play/Pause → CC30, Stop → CC31, Record → CC32, Master '
                  'volume → CC14. Use for DAW transport if supported.',
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Control labels card for renaming controls.
class _ControlLabelsCard extends ConsumerWidget {
  const _ControlLabelsCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controlsState = ref.watch(controlsProvider);
    final controlsCtrl = ref.read(controlsProvider.notifier);

    return Card(
      child: ExpansionTile(
        leading: const Icon(Icons.label_outline),
        title: const Text('Control labels'),
        subtitle: const Text('Rename faders, knobs, and buttons'),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tap a control label to rename it. Changes are saved '
                  'automatically.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                for (final bank in controlsState.banks)
                  _BankLabelsSection(
                    bank: bank,
                    controlsState: controlsState,
                    controlsCtrl: controlsCtrl,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BankLabelsSection extends StatelessWidget {
  const _BankLabelsSection({
    required this.bank,
    required this.controlsState,
    required this.controlsCtrl,
  });

  final ControlBank bank;
  final ControlsState controlsState;
  final ControlsController controlsCtrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          bank.name,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        for (final control in bank.controls)
          _ControlLabelTile(
            control: control,
            label: control.label,
            onLabelChanged: (label) =>
                controlsCtrl.updateControlLabel(control.id, label),
          ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _ControlLabelTile extends StatelessWidget {
  const _ControlLabelTile({
    required this.control,
    required this.label,
    required this.onLabelChanged,
  });

  final MidiControl control;
  final String label;
  final ValueChanged<String> onLabelChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(_iconForType(control.type)),
      title: Text(label),
      subtitle: Text('${control.type.name} · CC${control.mapping.controller}'),
      trailing: IconButton(
        icon: const Icon(Icons.edit),
        onPressed: () => _showEditDialog(context),
      ),
    );
  }

  IconData _iconForType(MidiControlType type) {
    switch (type) {
      case MidiControlType.fader:
        return Icons.vertical_align_center;
      case MidiControlType.knob:
        return Icons.settings_ethernet;
      case MidiControlType.momentaryButton:
        return Icons.smart_button;
      case MidiControlType.toggleButton:
        return Icons.toggle_on;
      case MidiControlType.latchButton:
        return Icons.lock_outline;
      case MidiControlType.xyPad:
        return Icons.crop_free;
    }
  }

  void _showEditDialog(BuildContext context) {
    final controller = TextEditingController(text: label);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Edit ${control.type.name} label'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Label',
            border: OutlineInputBorder(),
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
              onLabelChanged(controller.text.trim());
              Navigator.of(context).pop();
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _GuideSection extends StatelessWidget {
  const _GuideSection({required this.title, required this.lines});

  final String title;
  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Text(line, style: Theme.of(context).textTheme.bodySmall),
          ),
      ],
    );
  }
}
