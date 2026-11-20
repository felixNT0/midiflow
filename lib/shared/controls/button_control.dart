import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Performance button supporting momentary, toggle and latch modes.
///
/// Callbacks are supplied by the owner, which decides what MIDI values to
/// send on press/release/toggle.
class ButtonControl extends StatefulWidget {
  const ButtonControl({
    super.key,
    required this.label,
    required this.mode,
    this.active = false,
    this.enabled = true,
    this.onPress,
    this.onRelease,
    this.onToggle,
  });

  final String label;
  final ButtonMode mode;
  final bool active;
  final bool enabled;
  final VoidCallback? onPress;
  final VoidCallback? onRelease;
  final VoidCallback? onToggle;

  @override
  State<ButtonControl> createState() => _ButtonControlState();
}

class _ButtonControlState extends State<ButtonControl> {
  bool _pressed = false;

  bool get _highlighted {
    if (widget.mode == ButtonMode.momentary) return _pressed;
    return widget.active;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMomentary = widget.mode == ButtonMode.momentary;
    final highlighted = _highlighted;

    void press() {
      if (!widget.enabled) return;
      setState(() => _pressed = true);
      widget.onPress?.call();
    }

    void release() {
      if (!widget.enabled || !isMomentary) return;
      setState(() => _pressed = false);
      widget.onRelease?.call();
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: isMomentary ? (_) => press() : null,
      onTapUp: isMomentary ? (_) => release() : null,
      onTapCancel: isMomentary ? release : null,
      onTap: !isMomentary && widget.enabled
          ? () => widget.onToggle?.call()
          : null,
      child: Semantics(
        button: true,
        label: '${widget.label} ${widget.mode.name} button',
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.curve,
          height: 56,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: highlighted
                ? scheme.primary
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: highlighted ? scheme.primary : scheme.outlineVariant,
            ),
            boxShadow: highlighted
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: AnimatedDefaultTextStyle(
            duration: AppMotion.fast,
            style: TextStyle(
              color: highlighted ? scheme.onPrimary : scheme.onSurface,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
            child: Text(widget.label, overflow: TextOverflow.ellipsis),
          ),
        ),
      ),
    );
  }
}

enum ButtonMode { momentary, toggle, latch }
