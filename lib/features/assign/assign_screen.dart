import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/midi/controls_provider.dart';
import '../../application/midi/midi_provider.dart';
import '../../domain/midi/control_bank.dart';
import '../../domain/midi/midi_control.dart';

/// Guided control assignment: pick a control, edit its MIDI mapping,
/// send a test CC and follow Kontakt's own Learn workflow.
class AssignScreen extends ConsumerWidget {
  const AssignScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(controlsProvider);
    final control = state.selectedControl;

    return Scaffold(
      appBar: AppBar(title: const Text('Assign')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _BankBar(state: state),
          const SizedBox(height: 12),
          _ControlPicker(state: state),
          if (state.controls.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: Text('This bank has no controls yet.')),
            ),
          const SizedBox(height: 16),
          if (control != null) ...[
            _ControlEditor(control: control),
            const SizedBox(height: 16),
            _LearnCard(control: control),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddSheet(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Add control'),
      ),
    );
  }

  void _showAddSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('Add control')),
              for (final type in MidiControlType.values)
                ListTile(
                  leading: Icon(_typeIcon(type)),
                  title: Text(_typeLabel(type)),
                  onTap: () {
                    ref.read(controlsProvider.notifier).addControl(type);
                    Navigator.of(sheetContext).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  static IconData _typeIcon(MidiControlType t) => switch (t) {
    MidiControlType.fader => Icons.linear_scale,
    MidiControlType.knob => Icons.tune,
    MidiControlType.momentaryButton => Icons.smart_button,
    MidiControlType.toggleButton => Icons.toggle_on,
    MidiControlType.latchButton => Icons.lock,
    MidiControlType.xyPad => Icons.grid_on,
  };

  static String _typeLabel(MidiControlType t) => switch (t) {
    MidiControlType.fader => 'Fader',
    MidiControlType.knob => 'Knob',
    MidiControlType.momentaryButton => 'Momentary button',
    MidiControlType.toggleButton => 'Toggle button',
    MidiControlType.latchButton => 'Latch button',
    MidiControlType.xyPad => 'XY pad',
  };
}

class _ControlPicker extends ConsumerWidget {
  const _ControlPicker({required this.state});

  final ControlsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: state.selectedControlId,
            items: [
              for (final c in state.controls)
                DropdownMenuItem(value: c.id, child: Text(c.label)),
            ],
            onChanged: (id) =>
                ref.read(controlsProvider.notifier).selectControl(id),
          ),
        ),
      ),
    );
  }
}

class _ControlEditor extends ConsumerWidget {
  const _ControlEditor({required this.control});

  final MidiControl control;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(controlsProvider.notifier);
    final isXy = control.type == MidiControlType.xyPad;
    final isButton =
        control.type != MidiControlType.fader &&
        control.type != MidiControlType.knob &&
        !isXy;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              key: ValueKey('label-${control.id}'),
              initialValue: control.label,
              decoration: const InputDecoration(labelText: 'Label'),
              onChanged: (v) => ctrl.updateControl(
                control.copyWith(label: v.isEmpty ? control.label : v),
              ),
            ),
            const SizedBox(height: 8),
            _IntStepper(
              label: 'Channel (1-16)',
              value: control.mapping.channel,
              min: 1,
              max: 16,
              onChanged: (v) =>
                  _updateMapping(ref, control.mapping.copyWith(channel: v)),
            ),
            _IntStepper(
              label: 'CC controller (0-127)',
              value: control.mapping.controller,
              min: 0,
              max: 127,
              onChanged: (v) =>
                  _updateMapping(ref, control.mapping.copyWith(controller: v)),
            ),
            if (!isButton) ...[
              _IntStepper(
                label: 'Min value',
                value: control.mapping.minValue,
                min: 0,
                max: 127,
                onChanged: (v) =>
                    _updateMapping(ref, control.mapping.copyWith(minValue: v)),
              ),
              _IntStepper(
                label: 'Max value',
                value: control.mapping.maxValue,
                min: 0,
                max: 127,
                onChanged: (v) =>
                    _updateMapping(ref, control.mapping.copyWith(maxValue: v)),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Inverted'),
                value: control.mapping.inverted,
                onChanged: (v) =>
                    _updateMapping(ref, control.mapping.copyWith(inverted: v)),
              ),
            ],
            if (isXy) ...[
              const Divider(),
              Text('X axis', style: Theme.of(context).textTheme.titleSmall),
              _MappingEditor(
                mapping: control.xMapping ?? control.mapping,
                onChanged: (m) =>
                    ctrl.updateControl(control.copyWith(xMapping: m)),
              ),
              const SizedBox(height: 8),
              Text('Y axis', style: Theme.of(context).textTheme.titleSmall),
              _MappingEditor(
                mapping: control.yMapping ?? control.mapping,
                onChanged: (m) =>
                    ctrl.updateControl(control.copyWith(yMapping: m)),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text('Send test CC'),
                    onPressed: () =>
                        unawaited(ctrl.sendTestCc(control.mapping)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Delete control',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => ctrl.removeControl(control.id),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateMapping(WidgetRef ref, ControlMapping? mapping) {
    if (mapping == null) return;
    try {
      mapping.validate();
    } catch (_) {
      return; // keep last valid mapping
    }
    final ctrl = ref.read(controlsProvider.notifier);
    // For XY pads the primary mapping is only a fallback; update it anyway.
    ctrl.updateControl(control.copyWith(mapping: mapping));
  }
}

class _MappingEditor extends ConsumerWidget {
  const _MappingEditor({required this.mapping, required this.onChanged});

  final ControlMapping mapping;
  final ValueChanged<ControlMapping> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _IntStepper(
          label: 'Channel',
          value: mapping.channel,
          min: 1,
          max: 16,
          onChanged: (v) => _safe(mapping.copyWith(channel: v)),
        ),
        _IntStepper(
          label: 'CC',
          value: mapping.controller,
          min: 0,
          max: 127,
          onChanged: (v) => _safe(mapping.copyWith(controller: v)),
        ),
      ],
    );
  }

  void _safe(ControlMapping m) {
    try {
      m.validate();
      onChanged(m);
    } catch (_) {}
  }
}

class _IntStepper extends StatelessWidget {
  const _IntStepper({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        IconButton(
          icon: const Icon(Icons.remove),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        SizedBox(width: 48, child: Text('$value', textAlign: TextAlign.center)),
        IconButton(
          icon: const Icon(Icons.add),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

class _LearnCard extends ConsumerWidget {
  const _LearnCard({required this.control});

  final MidiControl control;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connected = ref.watch(midiControllerProvider).isConnected;
    final mapping = control.mapping;
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kontakt Learn',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'This control sends CC ${mapping.controller} on channel '
              '${mapping.channel} (values ${mapping.minValue}-${mapping.maxValue}'
              '${mapping.inverted ? ', inverted' : ''}).',
            ),
            const SizedBox(height: 8),
            const Text(
              '1. Send the test CC above.\n'
              '2. In Kontakt, right-click the target knob/slider and choose '
              '"Learn MIDI CC Automation" (or use the Automation tab → Learn '
              'for NativeUI instruments).\n'
              '3. Move this control on the Play screen.\n'
              '4. Confirm the parameter responds, then save your profile.',
            ),
            if (!connected) ...[
              const SizedBox(height: 8),
              Text(
                'No device connected — MIDI will not reach Kontakt until you '
                'connect in Settings.',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bank selector and management: switch pages, add (empty or from a
/// template), rename (long-press a chip) and delete.
class _BankBar extends ConsumerWidget {
  const _BankBar({required this.state});

  final ControlsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(controlsProvider.notifier);
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: state.banks.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final bank = state.banks[i];
                final selected = i == state.activeBankIndex;
                return GestureDetector(
                  onLongPress: () => _renameBank(context, ref, i, bank.name),
                  child: ChoiceChip(
                    label: Text(bank.name),
                    selected: selected,
                    onSelected: (_) => ctrl.switchBank(i),
                  ),
                );
              },
            ),
          ),
        ),
        IconButton(
          tooltip: 'Add bank',
          icon: const Icon(Icons.add),
          onPressed: () => _showAddBankSheet(context, ref),
        ),
        IconButton(
          tooltip: 'Delete bank',
          icon: const Icon(Icons.delete_outline),
          onPressed: state.banks.length > 1
              ? () => ctrl.removeBank(state.activeBankIndex)
              : null,
        ),
      ],
    );
  }

  void _showAddBankSheet(BuildContext context, WidgetRef ref) {
    final count = state.banks.length + 1;
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const ListTile(title: Text('New bank')),
              ListTile(
                leading: const Icon(Icons.add_box_outlined),
                title: const Text('Empty bank'),
                subtitle: const Text('Start from scratch'),
                onTap: () {
                  ref
                      .read(controlsProvider.notifier)
                      .addBank(name: 'Bank $count');
                  Navigator.of(sheetContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.equalizer),
                title: const Text('Mixer layout'),
                subtitle: const Text(
                  '8 faders + 8 pan knobs (FL Studio ch 9-16)',
                ),
                onTap: () {
                  ref
                      .read(controlsProvider.notifier)
                      .addBank(
                        name: 'Mixer $count',
                        controls: ControlBankTemplates.mixer().controls,
                      );
                  Navigator.of(sheetContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('Transport layout'),
                subtitle: const Text('Play, stop and record for FL Studio'),
                onTap: () {
                  ref
                      .read(controlsProvider.notifier)
                      .addBank(
                        name: 'Transport $count',
                        controls: ControlBankTemplates.transport().controls,
                      );
                  Navigator.of(sheetContext).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.music_note),
                title: const Text('Instrument layout'),
                subtitle: const Text('Volume, expression, filter, XY pad'),
                onTap: () {
                  ref
                      .read(controlsProvider.notifier)
                      .addBank(
                        name: 'Instrument $count',
                        controls: ControlBankTemplates.instrument().controls,
                      );
                  Navigator.of(sheetContext).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _renameBank(
    BuildContext context,
    WidgetRef ref,
    int index,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename bank'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.of(dialogContext).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name != null) {
      ref.read(controlsProvider.notifier).renameBank(index, name);
    }
  }
}
