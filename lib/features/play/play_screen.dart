import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/midi/bridge_provider.dart';
import '../../application/midi/controls_provider.dart';
import '../../application/midi/midi_provider.dart';
import '../../domain/midi/midi_control.dart';
import '../../infrastructure/midi/network/bridge_client.dart';
import '../../shared/controls/button_control.dart';
import '../../shared/controls/fader_control.dart';
import '../../shared/controls/knob_control.dart';
import '../../shared/controls/xy_pad_control.dart';
import '../../shared/theme/app_theme.dart';

/// Primary performance screen: bank switcher plus the active bank's
/// controls, grouped into TouchDAW-style fader and knob strips.
class PlayScreen extends ConsumerWidget {
  const PlayScreen({super.key, required this.onOpenSettings});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(controlsProvider);
    final midi = ref.watch(midiControllerProvider);
    final bridge = ref.watch(bridgeClientProvider);
    final controlsCtrl = ref.read(controlsProvider.notifier);
    final connected = midi.isConnected || bridge.isConnected;
    final controls = state.controls;
    final padControls = controls
        .where((c) => c.id.startsWith('pad-'))
        .toList();
    final drumControls = controls
        .where((c) => c.id.startsWith('drum-'))
        .toList();
    final padVolumeControl = controls
        .where((c) => c.id == 'pad-volume')
        .firstOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MIDIFlow'),
        toolbarHeight: 48, // Reduced header height
        actions: [
          _ConnectionChip(
            connected: connected,
            hasError:
                bridge.status == BridgeClientStatus.error ||
                bridge.lastError != null,
            deviceName: bridge.isConnected
                ? 'Bridge'
                : midi.selectedDevice?.name,
            onTap: onOpenSettings,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // Sticky header: bank tabs + channel selector stay fixed while scrolling
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Column(
              children: [
                _BankBar(state: state),
                if (state.activeBank?.id == 'bank-instrument' ||
                    state.activeBank?.id == 'bank-performance') ...[
                  const SizedBox(height: 6),
                  _LeadChannelBar(
                    leadChannel: controlsCtrl.leadChannel,
                    onSelect: controlsCtrl.setLeadChannel,
                  ),
                ],
                const SizedBox(height: 6),
              ],
            ),
          ),
          // Scrollable content area
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              children: [
                if (!connected)
                  Card(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    child: ListTile(
                      leading: Icon(
                        Icons.link_off,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      title: const Text('No MIDI device connected'),
                      subtitle: const Text(
                        'Controls are disabled. Connect in Settings.',
                      ),
                    ),
                  ),
                if (controls.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Center(child: Text('This bank is empty.')),
                  )
                else ...[
                  // Layer Volume Faders with On/Off toggles (Primary - Kontakt)
                  _Section(
                    title: 'Layer Volumes',
                    horizontal: true,
                    height: 252,
                    children: [
                      for (final c in controls.where(
                        (c) => c.id.startsWith('layer-vol-'),
                      ))
                        _layerTile(context, ref, c, controls, controlsCtrl, connected),
                    ],
                  ),
                  // Continuous Pads — assignable CC toggles for the Kontakt
                  // library's pad/drone controls (chromatic C-B labels).
                  if (padControls.isNotEmpty) ...[
                    _Section(
                      title: 'Continuous Pads',
                      children: [_padGrid(padControls, controlsCtrl, connected)],
                    ),
                    if (padVolumeControl != null)
                      _Section(
                        title: 'Pad Volume',
                        horizontal: true,
                        height: 180,
                        children: [
                          _faderTile(
                            context,
                            ref,
                            padVolumeControl,
                            controlsCtrl,
                            connected,
                          ),
                        ],
                      ),
                  ],
                  // Drum Pads — momentary pads assignable to drum articulations
                  if (drumControls.isNotEmpty)
                    _Section(
                      title: 'Drum Pads',
                      children: [
                        _drumGrid(drumControls, controlsCtrl, connected),
                      ],
                    ),
                  // Performance Controls Section (Knobs, Modulation, etc.)
                  _Section(
                    title: state.activeBank?.name ?? 'Performance',
                    horizontal: true,
                    children: [
                      for (final c in controls.where(
                        (c) => c.type == MidiControlType.knob &&
                            !c.id.startsWith('part-pan-') &&
                            !c.id.startsWith('mix-pan-'),
                      ))
                        _knobTile(context, ref, c, controlsCtrl, connected),
                    ],
                  ),
                  // Channel Volume Faders (Part volumes)
                  _Section(
                    title: 'Channel Volumes',
                    horizontal: true,
                    children: [
                      for (final c in controls.where(
                        (c) => c.type == MidiControlType.fader &&
                            !c.id.startsWith('layer-vol-'),
                      ))
                        _faderTile(context, ref, c, controlsCtrl, connected),
                    ],
                  ),
                  _Section(
                    title: 'XY Pad',
                    children: [
                      for (final c in controls.where(
                        (c) => c.type == MidiControlType.xyPad,
                      ))
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 8,
                          ),
                          child: SizedBox(
                            width: 340,
                            child: XyPadControl(
                              label: c.label,
                              xValue: c.normalizedValue,
                              yValue: c.yNormalized,
                              enabled: connected,
                              onChanged: (x, y) =>
                                  unawaited(controlsCtrl.setXY(c, x, y)),
                            ),
                          ),
                        ),
                    ],
                  ),
                  _Section(
                    title: 'Buttons',
                    children: [
                      for (final c in controls.where(
                        (c) =>
                            c.type != MidiControlType.fader &&
                            c.type != MidiControlType.knob &&
                            c.type != MidiControlType.xyPad &&
                            !c.id.startsWith('layer-toggle-') &&
                            !c.id.startsWith('pad-') &&
                            !c.id.startsWith('drum-'),
                      ))
                        _buttonTile(context, ref, c, controlsCtrl, connected),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 2×6 grid of continuous-pad toggles (CC pads for Kontakt assign).
  Widget _padGrid(
    List<MidiControl> pads,
    ControlsController ctrl,
    bool connected,
  ) {
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 10),
          Row(
            children: [
              for (var col = 0; col < 6; col++) ...[
                if (col > 0) const SizedBox(width: 10),
                Expanded(
                  child: _PadTile(
                    control: pads[row * 6 + col],
                    enabled: connected,
                    onToggle: () =>
                        unawaited(ctrl.buttonToggle(pads[row * 6 + col])),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  /// 4×4 grid of momentary drum pads.
  Widget _drumGrid(
    List<MidiControl> drums,
    ControlsController ctrl,
    bool connected,
  ) {
    return Column(
      children: [
        for (var row = 0; row < 4; row++) ...[
          if (row > 0) const SizedBox(height: 10),
          Row(
            children: [
              for (var col = 0; col < 4; col++) ...[
                if (col > 0) const SizedBox(width: 10),
                Expanded(
                  child: _DrumPad(
                    label: drums[row * 4 + col].label,
                    enabled: connected,
                    onPress: () =>
                        unawaited(ctrl.buttonPress(drums[row * 4 + col])),
                    onRelease: () =>
                        unawaited(ctrl.buttonRelease(drums[row * 4 + col])),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _faderTile(
    BuildContext context,
    WidgetRef ref,
    MidiControl c,
    ControlsController ctrl,
    bool connected,
  ) {
    return SizedBox(
      width: 76,
      height: 210,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: FaderControl(
          label: c.label,
          value: c.normalizedValue,
          midiValue: c.currentMidiValue,
          enabled: connected,
          onChanged: (v) => unawaited(ctrl.setNormalized(c, v)),
        ),
      ),
    );
  }

  /// Layer fader with its On/Off toggle stacked underneath — each pair
  /// drives one Kontakt/VST layer (volume CC + enable/mute CC).
  Widget _layerTile(
    BuildContext context,
    WidgetRef ref,
    MidiControl fader,
    List<MidiControl> controls,
    ControlsController ctrl,
    bool connected,
  ) {
    final toggleId = fader.id.replaceFirst('layer-vol-', 'layer-toggle-');
    MidiControl? toggle;
    for (final c in controls) {
      if (c.id == toggleId) {
        toggle = c;
        break;
      }
    }
    return SizedBox(
      width: 76,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          children: [
            SizedBox(
              height: 192,
              child: FaderControl(
                label: fader.label,
                value: fader.normalizedValue,
                midiValue: fader.currentMidiValue,
                enabled: connected,
                onChanged: (v) => unawaited(ctrl.setNormalized(fader, v)),
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 46,
              width: double.infinity,
              child: toggle == null
                  ? const SizedBox.shrink()
                  : ButtonControl(
                      label: 'On/Off',
                      mode: ButtonMode.toggle,
                      active: toggle.normalizedValue >= 0.5,
                      enabled: connected,
                      onToggle: () =>
                          unawaited(ctrl.buttonToggle(toggle!)),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _knobTile(
    BuildContext context,
    WidgetRef ref,
    MidiControl c,
    ControlsController ctrl,
    bool connected,
  ) {
    return SizedBox(
      width: 92,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: KnobControl(
          label: c.label,
          value: c.normalizedValue,
          midiValue: c.currentMidiValue,
          enabled: connected,
          onChanged: (v) => unawaited(ctrl.setNormalized(c, v)),
        ),
      ),
    );
  }

  Widget _buttonTile(
    BuildContext context,
    WidgetRef ref,
    MidiControl c,
    ControlsController ctrl,
    bool connected,
  ) {
    final mode = switch (c.type) {
      MidiControlType.momentaryButton => ButtonMode.momentary,
      MidiControlType.toggleButton => ButtonMode.toggle,
      MidiControlType.latchButton => ButtonMode.latch,
      _ => ButtonMode.momentary,
    };
    return SizedBox(
      width: 160,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: ButtonControl(
          label: c.label,
          mode: mode,
          active: c.normalizedValue >= 0.5,
          enabled: connected,
          onPress: () => unawaited(ctrl.buttonPress(c)),
          onRelease: () => unawaited(ctrl.buttonRelease(c)),
          onToggle: () => unawaited(ctrl.buttonToggle(c)),
        ),
      ),
    );
  }
}

/// Horizontally scrolling bank selector — the "mode" switcher.
class _BankBar extends ConsumerWidget {
  const _BankBar({required this.state});

  final ControlsState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (state.banks.isEmpty) return const SizedBox.shrink();
    final ctrl = ref.read(controlsProvider.notifier);
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: state.banks.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final bank = state.banks[i];
          final selected = i == state.activeBankIndex;
          return _Pill(
            label: bank.name,
            icon: Icons.graphic_eq,
            selected: selected,
            onTap: () => ctrl.switchBank(i),
          );
        },
      ),
    );
  }
}

/// Part selector shown on the Instrument bank: chooses which FL Studio
/// channel (1-8) the lead performance controls target.
class _LeadChannelBar extends StatelessWidget {
  const _LeadChannelBar({required this.leadChannel, required this.onSelect});

  final int leadChannel;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest
            .withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Channel',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 6),
          Row(
            children: List.generate(8, (i) {
              final part = i + 1;
              final selected = part == leadChannel;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < 7 ? 6 : 0),
                  child: GestureDetector(
                    onTap: () => onSelect(part),
                    child: AnimatedContainer(
                      duration: AppMotion.normal,
                      curve: AppMotion.curve,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                                .withValues(alpha: 0.25)
                            : Theme.of(context).colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'P$part',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: selected
                                    ? Theme.of(context).colorScheme.primary
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                fontSize: 14,
                              ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// Animated pill button used by the bank and part selectors — slides a
/// highlight in with the theme motion curve.
class _Pill extends StatelessWidget {
  const _Pill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.normal,
        curve: AppMotion.curve,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? scheme.primary.withValues(alpha: 0.20)
              : scheme.surfaceContainerHighest.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.8)
                : Colors.transparent,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.25),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 15,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pad-style toggle button used by the Continuous Pads grid — glows while
/// its CC toggle state is on so assigned Kontakt pad layers are visible.
/// Momentary drum pad — fires on press, releases on let-go, and flashes
/// while held so hits are visible during fast drum programming.
class _DrumPad extends StatefulWidget {
  const _DrumPad({
    required this.label,
    required this.enabled,
    required this.onPress,
    required this.onRelease,
  });

  final String label;
  final bool enabled;
  final VoidCallback onPress;
  final VoidCallback onRelease;

  @override
  State<_DrumPad> createState() => _DrumPadState();
}

class _DrumPadState extends State<_DrumPad> {
  bool _pressed = false;

  void _down() {
    if (!widget.enabled) return;
    setState(() => _pressed = true);
    widget.onPress();
  }

  void _up() {
    if (!widget.enabled) return;
    setState(() => _pressed = false);
    widget.onRelease();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: widget.enabled ? 1.0 : 0.45,
      child: GestureDetector(
        onTapDown: (_) => _down(),
        onTapUp: (_) => _up(),
        onTapCancel: () => _up(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 80),
          height: 62,
          decoration: BoxDecoration(
            color: _pressed
                ? scheme.primary.withValues(alpha: 0.4)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _pressed
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.6),
              width: _pressed ? 2 : 1,
            ),
          ),
          child: Center(
            child: Text(
              widget.label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: _pressed ? scheme.primary : scheme.onSurface,
                  ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PadTile extends StatelessWidget {
  const _PadTile({
    required this.control,
    required this.enabled,
    required this.onToggle,
  });

  final MidiControl control;
  final bool enabled;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = control.normalizedValue >= 0.5;
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: Material(
        color: active
            ? scheme.primary.withValues(alpha: 0.3)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onToggle : null,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            height: 72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: active
                    ? scheme.primary
                    : scheme.outlineVariant.withValues(alpha: 0.6),
                width: active ? 2 : 1,
              ),
              boxShadow: active
                  ? [
                      BoxShadow(
                        color: scheme.primary.withValues(alpha: 0.35),
                        blurRadius: 12,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Text(
                control.label,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: active ? scheme.primary : scheme.onSurface,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.children,
    this.horizontal = false,
    this.height = 220,
  });

  final String title;
  final List<Widget> children;
  final bool horizontal;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 4),
          child: Text(
            title.toUpperCase(),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              letterSpacing: 1.6,
            ),
          ),
        ),
        if (horizontal)
          SizedBox(
            height: height,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: children,
            ),
          )
        else
          Wrap(spacing: 12, runSpacing: 12, children: children),
      ],
    );
  }
}

class _ConnectionChip extends StatelessWidget {
  const _ConnectionChip({
    required this.connected,
    required this.hasError,
    required this.deviceName,
    required this.onTap,
  });

  final bool connected;
  final bool hasError;
  final String? deviceName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color color;
    final IconData icon;
    final String label;
    if (connected) {
      color = Colors.greenAccent;
      icon = Icons.link;
      label = deviceName ?? 'Connected';
    } else if (hasError) {
      color = Colors.redAccent;
      icon = Icons.error_outline;
      label = 'Connection error';
    } else {
      color = scheme.onSurfaceVariant;
      icon = Icons.link_off;
      label = 'Not connected';
    }
    return ActionChip(
      avatar: connected
          ? const _PulseDot()
          : Icon(icon, size: 16, color: color),
      label: Text(label),
      labelStyle: TextStyle(color: color),
      side: BorderSide(color: color.withValues(alpha: 0.4)),
      onPressed: onTap,
    );
  }
}

/// Small pulsing dot shown in the connection chip while linked.
class _PulseDot extends StatefulWidget {
  const _PulseDot();

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.greenAccent,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
