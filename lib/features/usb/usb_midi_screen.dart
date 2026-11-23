import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/midi/midi_provider.dart';
import '../../infrastructure/midi/midi_device_model.dart';
import '../../infrastructure/midi/midi_service.dart';

/// USB MIDI connection screen for USB MIDI devices.
class UsbMidiScreen extends ConsumerWidget {
  const UsbMidiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final midi = ref.watch(midiControllerProvider);
    final controller = ref.read(midiControllerProvider.notifier);

    // Filter for USB devices only (already filtered by connection mode)
    final usbDevices = midi.filteredDevices
        .where((d) => d.kind == MidiDeviceKind.usb)
        .toList();

    return Scaffold(
      appBar: AppBar(title: const Text('USB MIDI')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _StatusCard(state: midi),
          const SizedBox(height: 16),
          _DeviceCard(
            state: midi,
            controller: controller,
            devices: usbDevices,
          ),
          const SizedBox(height: 16),
          _InstructionsCard(),
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
            Text('USB MIDI Status', style: Theme.of(context).textTheme.titleMedium),
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
  const _DeviceCard({
    required this.state,
    required this.controller,
    required this.devices,
  });

  final MidiState state;
  final MidiController controller;
  final List<MidiDeviceInfo> devices;

  @override
  Widget build(BuildContext context) {
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
                    'USB Devices (${devices.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  tooltip: 'Scan for USB MIDI devices',
                  icon: const Icon(Icons.refresh),
                  onPressed: state.busy ? null : controller.refreshDevices,
                ),
              ],
            ),
            if (devices.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('No USB MIDI devices found.\n\nConnect a USB MIDI device to your computer and it will appear here.'),
              )
            else
              for (final device in devices) _UsbDeviceTile(device: device),
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

class _UsbDeviceTile extends ConsumerWidget {
  const _UsbDeviceTile({required this.device});

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
        Icons.usb,
        color: selected ? Theme.of(context).colorScheme.primary : Colors.grey,
      ),
      title: Text(device.name),
      subtitle: Text(
        '${device.kind.name} · ${device.inputPorts.length} in · ${device.outputPorts.length} out',
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

class _InstructionsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('How to Connect', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _InstructionStep(
              number: '1',
              text: 'Connect USB MIDI device to your computer',
            ),
            _InstructionStep(
              number: '2',
              text: 'Tap "Scan for USB MIDI devices" above',
            ),
            _InstructionStep(
              number: '3',
              text: 'Select your device from the list',
            ),
            _InstructionStep(
              number: '4',
              text: 'Tap "Connect" to establish the link',
            ),
            const SizedBox(height: 8),
            Text(
              'USB MIDI provides the lowest latency and most reliable connection.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                number,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }
}
