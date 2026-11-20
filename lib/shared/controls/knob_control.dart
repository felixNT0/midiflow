import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Rotary knob control. Vertical drag adjusts [value] (normalized 0-1);
/// Shift+drag (or fine mode) adjusts at half sensitivity for desktop.
///
/// Interaction feedback: the knob presses in (scale + glow) while being
/// dragged and fires a light haptic tick on grab.
class KnobControl extends StatefulWidget {
  const KnobControl({
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
  final int? midiValue;

  @override
  State<KnobControl> createState() => _KnobControlState();
}

class _KnobControlState extends State<KnobControl> {
  bool _dragging = false;

  void _setDragging(bool v) {
    if (_dragging == v || !mounted) return;
    setState(() => _dragging = v);
  }

  void _drag(DragUpdateDetails details) {
    if (!widget.enabled) return;
    final fine = HardwareKeyboard.instance.isShiftPressed;
    final sensitivity = fine ? 0.005 : 0.01;
    final next = (widget.value - details.delta.dy * sensitivity).clamp(
      0.0,
      1.0,
    );
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final knobColor = widget.enabled
        ? scheme.primary
        : scheme.onSurfaceVariant;
    // Pick the most readable text color for the knob face.
    final onKnob = knobColor.computeLuminance() > 0.45
        ? Colors.black87
        : Colors.white;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: widget.enabled
          ? (_) {
              _setDragging(true);
              HapticFeedback.lightImpact();
            }
          : null,
      onVerticalDragUpdate: widget.enabled ? _drag : null,
      onVerticalDragEnd: widget.enabled ? (_) => _setDragging(false) : null,
      onVerticalDragCancel: widget.enabled ? () => _setDragging(false) : null,
      onTapDown: widget.enabled
          ? (_) {
              _setDragging(true);
              widget.onChanged(0.5);
            }
          : null,
      onTapUp: widget.enabled ? (_) => _setDragging(false) : null,
      onTapCancel: widget.enabled ? () => _setDragging(false) : null,
      child: Semantics(
        label: widget.label,
        value: '${(widget.value * 100).round()}%',
        slider: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedScale(
              scale: _dragging ? 0.9 : 1.0,
              duration: AppMotion.fast,
              curve: AppMotion.curve,
              child: AnimatedContainer(
                duration: AppMotion.fast,
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: _dragging
                      ? [
                          BoxShadow(
                            color: knobColor.withValues(alpha: 0.55),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ]
                      : null,
                ),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: widget.value, end: widget.value),
                  duration: AppMotion.fast,
                  curve: AppMotion.curve,
                  builder: (context, animated, _) => CustomPaint(
                    painter: _KnobPainter(
                      fraction: animated,
                      color: knobColor,
                      trackColor: scheme.surfaceContainerHighest,
                      active: _dragging,
                    ),
                    child: Center(
                      child: Text(
                        widget.midiValue?.toString() ??
                            '${(widget.value * 100).round()}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: onKnob,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              shadows: [
                                Shadow(
                                  color: onKnob == Colors.white
                                      ? Colors.black87
                                      : Colors.white70,
                                  blurRadius: 2,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.label,
              style: Theme.of(context).textTheme.bodySmall,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _KnobPainter extends CustomPainter {
  _KnobPainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
    this.active = false,
  });

  final double fraction;
  final Color color;
  final Color trackColor;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 4;
    const startAngle = 3 * 3.14159265 / 4;
    const sweep = 3 * 3.14159265 / 2;
    final arc = sweep * fraction.clamp(0.0, 1.0);

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweep,
      false,
      trackPaint,
    );

    // Soft glow under the value arc while dragging.
    if (active) {
      final glowPaint = Paint()
        ..color = color.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        arc,
        false,
        glowPaint,
      );
    }

    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      arc,
      false,
      valuePaint,
    );

    canvas.drawCircle(center, radius * 0.55, Paint()..color = color);
    canvas.drawCircle(
      center,
      radius * 0.55,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_KnobPainter old) =>
      old.fraction != fraction ||
      old.color != color ||
      old.active != active;
}
