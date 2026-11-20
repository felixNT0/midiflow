import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Vertical fader control. [value] is normalized 0.0-1.0 (top = 1.0).
/// The thumb glides to its target so programmatic updates feel smooth;
/// direct drags stay responsive because each new target retargets quickly.
class FaderControl extends StatelessWidget {
  const FaderControl({
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
    return _DragToValue(
      label: label,
      value: value,
      enabled: enabled,
      midiValue: midiValue,
      builder: (context, v, active) => Column(
        children: [
          Text(
            '$label${midiValue != null ? ' · $midiValue' : ''}',
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              width: 56,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
              ),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final h = constraints.maxHeight;
                  final thumbH = 28.0;
                  final travel = (h - thumbH).clamp(0.0, double.infinity);
                  final top = travel * (1.0 - v);
                  return Stack(
                    children: [
                      Center(
                        child: Container(
                          width: 4,
                          height: h - 8,
                          color: Theme.of(context).colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.3),
                        ),
                      ),
                      TweenAnimationBuilder<double>(
                        tween: Tween(begin: top, end: top),
                        duration: AppMotion.fast,
                        curve: AppMotion.curve,
                        builder: (context, animatedTop, _) => Positioned(
                          top: animatedTop,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              width: 44,
                              height: thumbH,
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
                                    offset: const Offset(0, 2),
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

/// Shared drag handling: converts vertical drag position to normalized value.
class _DragToValue extends StatefulWidget {
  const _DragToValue({
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
  State<_DragToValue> createState() => _DragToValueState();
}

class _DragToValueState extends State<_DragToValue> {
  bool _dragging = false;

  void _setDragging(bool v) {
    if (_dragging == v || !mounted) return;
    setState(() => _dragging = v);
  }

  void _emitFromLocal(Offset local) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final dy = (local.dy / box.size.height).clamp(0.0, 1.0);
    widget.onChanged(1.0 - dy);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: enabled
          ? (details) {
              _setDragging(true);
              HapticFeedback.lightImpact();
              _emitFromLocal(details.localPosition);
            }
          : null,
      onVerticalDragUpdate: enabled
          ? (details) => _emitFromLocal(details.localPosition)
          : null,
      onVerticalDragEnd: enabled ? (_) => _setDragging(false) : null,
      onVerticalDragCancel: enabled ? () => _setDragging(false) : null,
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
