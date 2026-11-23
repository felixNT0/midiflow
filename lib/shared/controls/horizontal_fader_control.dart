import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Horizontal fader control. [value] is normalized 0.0-1.0 (left = 0.0, right = 1.0).
/// The thumb glides to its target so programmatic updates feel smooth;
/// direct drags stay responsive because each new target retargets quickly.
class HorizontalFaderControl extends StatelessWidget {
  const HorizontalFaderControl({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.midiValue,
  });

  final String label;
  final double value;
  final ValueChanged<double> onChanged;
  final bool enabled;

  /// Optional raw MIDI value shown alongside the normalized position.
  final int? midiValue;

  @override
  Widget build(BuildContext context) {
    return _HorizontalDragToValue(
      label: label,
      value: value,
      enabled: enabled,
      midiValue: midiValue,
      builder: (context, v, active) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$label${midiValue != null ? ' · $midiValue' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 56,
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final thumbW = 28.0;
                  final travel = (w - thumbW).clamp(0.0, double.infinity);
                  final left = travel * v;
                  return Stack(
                    children: [
                      Center(
                        child: Container(
                          height: 4,
                          width: w - 8,
                          color: Theme.of(context).colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: left, end: left),
                        duration: AppMotion.fast,
                        curve: AppMotion.curve,
                        builder: (context, animatedLeft, _) => Positioned(
                          left: animatedLeft,
                          top: 0,
                          bottom: 0,
                          child: Center(
                            child: Container(
                              width: thumbW,
                              height: 44,
                              decoration: BoxDecoration(
                                color: enabled
                                    ? (active
                                          ? Theme.of(context)
                                                .colorScheme
                                                .secondary
                                          : Theme.of(context)
                                                .colorScheme
                                                .primary)
                                    : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                borderRadius: BorderRadius.circular(7),
                                boxShadow: [
                                  BoxShadow(
                                    color: active
                                        ? Theme.of(context)
                                              .colorScheme
                                              .secondary
                                              .withValues(alpha: 0.6)
                                        : Colors.black.withValues(
                                            alpha: 0.35,
                                          ),
                                    blurRadius: active ? 14 : 6,
                                    offset: const Offset(2, 0),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      onChanged: onChanged,
    );
  }
}

/// Shared drag handling: converts horizontal drag position to normalized value.
class _HorizontalDragToValue extends StatefulWidget {
  const _HorizontalDragToValue({
    required this.label,
    required this.value,
    required this.enabled,
    required this.builder,
    required this.onChanged,
    this.midiValue,
  });

  final String label;
  final double value;
  final bool enabled;
  final int? midiValue;
  final Widget Function(BuildContext context, double value, bool active)
  builder;
  final ValueChanged<double> onChanged;

  @override
  State<_HorizontalDragToValue> createState() => _HorizontalDragToValueState();
}

class _HorizontalDragToValueState extends State<_HorizontalDragToValue> {
  bool _dragging = false;

  void _setDragging(bool v) {
    if (_dragging == v || !mounted) return;
    setState(() => _dragging = v);
  }

  void _emitFromLocal(Offset local) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final dx = (local.dx / box.size.width).clamp(0.0, 1.0);
    widget.onChanged(dx);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onHorizontalDragStart: enabled
          ? (details) {
              _setDragging(true);
              HapticFeedback.lightImpact();
              _emitFromLocal(details.localPosition);
            }
          : null,
      onHorizontalDragUpdate: enabled
          ? (details) => _emitFromLocal(details.localPosition)
          : null,
      onHorizontalDragEnd: enabled ? (_) => _setDragging(false) : null,
      onHorizontalDragCancel: enabled ? () => _setDragging(false) : null,
      onTapDown: enabled
          ? (details) {
              _setDragging(true);
              _emitFromLocal(details.localPosition);
            }
          : null,
      onTapUp: enabled ? (_) => _setDragging(false) : null,
      onTapCancel: enabled ? () => _setDragging(false) : null,
      child: Semantics(
        label: widget.label,
        value: '${(widget.value * 100).round()}%',
        slider: true,
        child: widget.builder(context, widget.value, _dragging),
      ),
    );
  }
}
