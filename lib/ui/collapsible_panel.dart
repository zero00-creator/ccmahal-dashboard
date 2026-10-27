import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'glass.dart';

/// A glass panel with a header you tap to open or close it, used for Alerts
/// and Settings in the desktop layout's right column. The header can show a
/// badge count.
class CollapsiblePanel extends StatelessWidget {
  const CollapsiblePanel({
    super.key,
    required this.id,
    required this.title,
    required this.icon,
    required this.open,
    required this.onToggle,
    required this.style,
    required this.child,
    this.badgeCount = 0,
    this.blurEnabled = true,
  });

  /// Names the header key: `panel-<id>`.
  final String id;
  final String title;
  final IconData icon;
  final bool open;
  final VoidCallback onToggle;
  final GlassStyle style;

  /// Shown only while open.
  final Widget child;

  /// When above zero, a badge on the icon (key `alert-badge`).
  final int badgeCount;
  final bool blurEnabled;

  @override
  Widget build(BuildContext context) {
    final glyph = Icon(icon, size: 22, color: style.accent);
    return GlassPanel(
      style: style,
      blurEnabled: blurEnabled,
      radius: Radii.card,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: title,
            child: InkWell(
              key: ValueKey('panel-$id'),
              borderRadius: BorderRadius.circular(Radii.card),
              onTap: onToggle,
              child: Container(
                constraints: const BoxConstraints(minHeight: minTap + 8),
                padding: const EdgeInsets.symmetric(horizontal: Space.x4),
                child: Row(
                  children: [
                    if (badgeCount > 0)
                      Badge(
                        key: const ValueKey('alert-badge'),
                        label: Text('$badgeCount'),
                        child: glyph,
                      )
                    else
                      glyph,
                    const SizedBox(width: Space.x3),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: style.ink,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: Motion.scaled(context, Motion.quick),
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: style.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (open) child,
        ],
      ),
    );
  }
}
