import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/midi/ble_bridge_provider.dart';
import '../../application/midi/bridge_provider.dart';

/// Desktop bridge control panel: runs the TCP server, shows the pairing
/// token and LAN address, and lists connected controllers.
class BridgeScreen extends ConsumerWidget {
  const BridgeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(bridgeServerProvider);
    final ctrl = ref.read(bridgeServerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Desktop Bridge')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.wifi,
                        color: state.running
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Wi-Fi Bridge (TCP)',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Spacer(),
                      if (state.starting || state.stopping)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: Icon(state.running ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        state.running ? 'Stop Wi-Fi bridge' : 'Start Wi-Fi bridge',
                      ),
                      onPressed: state.starting || state.stopping
                          ? null
                          : (state.running ? ctrl.stop : ctrl.start),
                    ),
                  ),
                  if (state.error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      state.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _BleBridgeCard(),
          if (state.running) ...[
            const SizedBox(height: 16),
            _PairingCard(state: state),
            const SizedBox(height: 16),
            _ClientsCard(state: state),
            const SizedBox(height: 16),
            const _DawInstructionsCard(),
          ],
        ],
      ),
    );
  }
}

class _PairingCard extends StatelessWidget {
  const _PairingCard({required this.state});

  final BridgeServerState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pair a controller',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            _Row(label: 'Port', value: '${state.port} (TCP)'),
            _Row(label: 'Endpoint', value: state.endpointName ?? '—'),
            _Row(
              label: 'Addresses',
              value: state.lanAddresses.isEmpty
                  ? 'unavailable'
                  : state.lanAddresses.join(', '),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: SelectableText(
                    'Token: ${state.token}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Copy token',
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: state.token ?? ''));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Token copied')),
                    );
                  },
                ),
              ],
            ),
            Text(
              'Enter the address and token in the MIDIFlow app on your '
              'phone/tablet (Settings → Connect to computer). Both devices '
              'must be on the same network.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientsCard extends StatelessWidget {
  const _ClientsCard({required this.state});

  final BridgeServerState state;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Connected controllers (${state.clients.length})',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (state.clients.isEmpty)
              const Text('No controllers connected.')
            else
              for (final c in state.clients)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.smartphone, size: 20),
                  title: Text(c.name),
                  subtitle: Text('${c.id} · ${c.messagesReceived} messages'),
                ),
          ],
        ),
      ),
    );
  }
}

/// Expandable setup guides: connecting the phone, then per-DAW setup for
/// FL Studio and Logic Pro.
class _DawInstructionsCard extends StatelessWidget {
  const _DawInstructionsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Column(
        children: const [
          _GuideTile(
            title: '1 · Connect phone to computer',
            steps: [
              'Keep this Bridge screen open on the laptop — the bridge '
                  'starts automatically and shows a pairing token and '
                  'network address.',
              'On the phone, open Settings → Connect to computer.',
              'Enter the laptop address and token shown above, then tap '
                  'Connect. Both devices must be on the same Wi-Fi '
                  'network.',
              'Important: if you switch Wi-Fi networks (home, church, '
                  'hotspot), the laptop IP address will change — always '
                  'check this screen and update the address on the phone '
                  'before connecting.',
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

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}

/// BLE bridge card for Bluetooth LE MIDI connections.
class _BleBridgeCard extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bleState = ref.watch(bleBridgeProvider);
    final bleCtrl = ref.read(bleBridgeProvider.notifier);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.bluetooth,
                  color: bleState.running
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Bluetooth LE Bridge (Independent)',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                if (bleState.starting)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Allow phones/tablets to connect via Bluetooth instead of Wi-Fi. '
              'No network required — just enable Bluetooth on both devices. '
              'This runs independently from the Wi-Fi bridge above.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: Icon(bleState.running ? Icons.stop : Icons.play_arrow),
                label: Text(
                  bleState.running ? 'Stop BLE bridge' : 'Start BLE bridge',
                ),
                onPressed: bleState.starting
                    ? null
                    : (bleState.running ? bleCtrl.stop : bleCtrl.start),
              ),
            ),
            if (bleState.running) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 8,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Advertising as "MIDIFlow Bridge"',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
              if (bleState.connectedClients > 0)
                Text(
                  '${bleState.connectedClients} client(s) connected',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
            if (bleState.error != null) ...[
              const SizedBox(height: 8),
              Text(
                bleState.error!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
