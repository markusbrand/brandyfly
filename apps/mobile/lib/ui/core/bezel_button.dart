import 'package:flutter/material.dart';

import 'theme/cockpit_tokens.dart';

/// A cockpit "bezel key": thick outer bezel, inset icon, high-contrast pressed
/// state without animation, and an optional glass-cyan lit ring.
///
/// Fills its parent; the whole box is the hit target. When [onPressed] is null
/// the key renders dimmed and ignores presses.
class BezelButton extends StatefulWidget {
  const BezelButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.lit = false,
    this.tooltip,
    this.child,
  });

  final IconData icon;
  final String semanticLabel;
  final String? tooltip;
  final VoidCallback? onPressed;

  /// Glass-cyan ring, e.g. recenter while the map is center-locked.
  final bool lit;

  /// Optional content replacing the icon (e.g. a zoom read-out).
  final Widget? child;

  @override
  State<BezelButton> createState() => _BezelButtonState();
}

class _BezelButtonState extends State<BezelButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed != value) setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final ringColor = !enabled
        ? CockpitTokens.bezelEdge.withAlpha(90)
        : widget.lit
        ? CockpitTokens.glassCyan
        : CockpitTokens.bezelEdge;
    final iconColor = !enabled
        ? CockpitTokens.inkMuted.withAlpha(90)
        : widget.lit
        ? CockpitTokens.glassCyan
        : CockpitTokens.ink;

    Widget key = Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapUp: enabled ? (_) => _setPressed(false) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTap: widget.onPressed,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final shortest = constraints.biggest.shortestSide;
            final safeShortest = shortest.isFinite ? shortest : 48.0;
            final iconSize = (safeShortest * 0.5).clamp(10.0, 40.0);
            final bezelWidth = safeShortest < 36 ? 1.5 : 2.0;
            return DecoratedBox(
              decoration: BoxDecoration(
                color: _pressed
                    ? CockpitTokens.nightPanel
                    : CockpitTokens.bezel,
                borderRadius: BorderRadius.circular(
                  (safeShortest * 0.18).clamp(4.0, 14.0),
                ),
                border: Border.all(color: ringColor, width: bezelWidth),
                boxShadow: _pressed
                    ? const [
                        BoxShadow(
                          color: Colors.black,
                          blurRadius: 2,
                          spreadRadius: -1,
                        ),
                      ]
                    : const [
                        BoxShadow(
                          color: Color(0x99000000),
                          blurRadius: 4,
                          offset: Offset(0, 2),
                        ),
                      ],
              ),
              child: Center(
                child:
                    widget.child ??
                    Icon(widget.icon, size: iconSize, color: iconColor),
              ),
            );
          },
        ),
      ),
    );

    final tooltip = widget.tooltip;
    if (tooltip != null && enabled) {
      key = Tooltip(message: tooltip, child: key);
    }
    return key;
  }
}
