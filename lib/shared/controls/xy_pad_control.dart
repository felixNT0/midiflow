import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Continuous XY pad. [xValue]/[yValue] are normalized 0.0-1.0
/// (bottom-left origin, matching screen coordinates).
class XyPadControl extends StatelessWidget {
  const XyPadControl({
    super.key,
    required this.label,
    required this.xValue,
    required this.yValue,
    required this.onChanged,
    this.enabled = true,
  });

  final String label;
  final double xValue;
  final double yValue;
  final void Function(double x, double y) onChanged;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 4),
        AspectRatio(
          aspectRatio: 1.4,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              final h = constraints.maxHeight;
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: enabled
                    ? (d) => _emit(d.localPosition, w, h)
                    : null,
                onPanUpdate: enabled
                    ? (d) => _emit(d.localPosition, w, h)
                    : null,
                onTapDown: enabled ? (d) => _emit(d.localPosition, w, h) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Stack(
                    children: [
                      // Axis labels
                      Positioned(
                        left: 6,
                        bottom: 2,
                        child: Text(
                          'Y',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      Positioned(
                        right: 6,
                        top: 2,
                        child: Text(
                          'X',
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ),
                      TweenAnimationBuilder<Offset>(
                        tween: Tween(
                          begin: Offset.zero,
                          end: Offset(w * xValue - 12, h * (1 - yValue) - 12),
                        ),
                        duration: AppMotion.fast,
                        curve: AppMotion.curve,
                        builder: (context, pos, _) => Positioned(
                          left: pos.dx,
                          top: pos.dy,
                          child: IgnorePointer(
                            child: Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.9),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.4),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _emit(Offset local, double w, double h) {
    onChanged(
      (local.dx / w).clamp(0.0, 1.0),
      (1.0 - local.dy / h).clamp(0.0, 1.0),
    );
  }
}
