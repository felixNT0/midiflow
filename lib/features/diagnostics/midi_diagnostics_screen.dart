import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/midi/midi_provider.dart';
import '../../infrastructure/midi/midi_device_model.dart';
import '../../infrastructure/midi/midi_message_model.dart';
import '../../infrastructure/midi/midi_service.dart';

/// Development screen for inspecting and exercising the MIDI engine.
class MidiDiagnosticsScreen extends ConsumerWidget {
  const MidiDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final midi = ref.watch(midiControllerProvider);
    final controller = ref.read(midiControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('MIDI Diagnostics')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(state: midi),
          const SizedBox(height: 16),
          _DeviceCard(state: midi, controller: controller),
          const SizedBox(height: 16),
          _SendCard(state: midi, controller: controller),
          const SizedBox(height: 16),
          _MessageLogCard(state: midi, controller: controller),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state});

  final MidiState state;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (state.status) {
      MidiEngineStatus.uninitialized => ('Uninitialized', Colors.grey),
      MidiEngineStatus.initializing => ('Initializing…', Colors.orange),
      MidiEngineStatus.ready => ('Ready', Colors.green),
      MidiEngineStatus.error => ('Error', Colors.red),
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('MIDI Engine', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.circle, size: 12, color: color),
                const SizedBox(width: 8),
                Text(label),
                if (state.busy) ...[
                  const SizedBox(width: 16),
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
            if (state.error != null) ...[
              const SizedBox(height: 8),
              Text(
                state.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({required this.state, required this.controller});

  final MidiState state;
  final MidiController controller;

  @override
  Widget build(BuildContext context) {
    final devices = state.filteredDevices;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Devices (${devices.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh devices',
                  icon: const Icon(Icons.refresh),
                  onPressed: state.busy ? null : controller.refreshDevices,
                ),
              ],
            ),
            if (devices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No MIDI devices found.'),
              )
            else
              for (final device in devices) _DeviceTile(device: device),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: Icon(state.isConnected ? Icons.link_off : Icons.link),
                label: Text(state.isConnected ? 'Disconnect' : 'Connect'),
                onPressed: state.selectedDevice == null || state.busy
                    ? null
                    : (state.isConnected
                          ? controller.disconnectSelected
                          : controller.connectSelected),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceTile extends ConsumerWidget {
  const _DeviceTile({required this.device});

  final MidiDeviceInfo device;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected =
        ref.watch(midiControllerProvider).selectedDeviceId == device.id;
    final state = device.connectionState;
    final (stateLabel, stateColor) = switch (state) {
      MidiDeviceConnectionState.connected => ('Connected', Colors.green),
      MidiDeviceConnectionState.connecting => ('Connecting…', Colors.orange),
      MidiDeviceConnectionState.disconnecting => (
        'Disconnecting…',
        Colors.orange,
      ),
      _ => ('Disconnected', Colors.grey),
    };

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_off,
      ),
      title: Text(device.name),
      subtitle: Text(
        '${device.kind.name} · in:${device.inputPorts.length} '
        'out:${device.outputPorts.length}',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.circle, size: 10, color: stateColor),
          const SizedBox(width: 4),
          Text(stateLabel, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
      onTap: () =>
          ref.read(midiControllerProvider.notifier).selectDevice(device.id),
    );
  }
}

class _SendCard extends StatelessWidget {
  const _SendCard({required this.state, required this.controller});

  final MidiState state;
  final MidiController controller;

  @override
  Widget build(BuildContext context) {
    final canSend = state.isConnected && !state.busy;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Send MIDI CC',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _LabeledSlider(
                    label: 'Channel',
                    value: state.channel.toDouble(),
                    min: midiMinChannel.toDouble(),
                    max: midiMaxChannel.toDouble(),
                    divisions: midiMaxChannel - midiMinChannel,
                    onChanged: (v) => controller.setChannel(v.round()),
                  ),
                ),
              ],
            ),
            _LabeledSlider(
              label: 'Controller (CC ${state.controller})',
              value: state.controller.toDouble(),
              min: midiMinValue.toDouble(),
              max: midiMaxValue.toDouble(),
              divisions: midiMaxValue,
              onChanged: (v) => controller.setController(v.round()),
            ),
            _LabeledSlider(
              label: 'Value (${state.ccValue})',
              value: state.ccValue.toDouble(),
              min: midiMinValue.toDouble(),
              max: midiMaxValue.toDouble(),
              divisions: midiMaxValue,
              onChanged: (v) => controller.setCcValue(v.round()),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.send),
                label: const Text('Send MIDI CC'),
                onPressed: canSend ? controller.sendControlChange : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LabeledSlider extends StatelessWidget {
  const _LabeledSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _MessageLogCard extends StatelessWidget {
  const _MessageLogCard({required this.state, required this.controller});

  final MidiState state;
  final MidiController controller;

  @override
  Widget build(BuildContext context) {
    final messages = state.messages.reversed.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Incoming MIDI (${state.messages.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Clear log',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: state.messages.isEmpty
                      ? null
                      : controller.clearMessageLog,
                ),
              ],
            ),
            if (messages.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No MIDI messages received yet.'),
              )
            else
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final m = messages[index];
                    return Text(
                      m.describe(),
                      style: Theme.of(context).textTheme.bodySmall,
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
