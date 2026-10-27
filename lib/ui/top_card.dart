import 'package:flutter/material.dart';

import '../environment.dart';
import '../theme/tokens.dart';
import 'glass.dart';
import 'sun_arc.dart';

/// The glass card over the office: menu button, session name, one status
/// line and the sun arc.
class TopCard extends StatelessWidget {
  const TopCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.env,
    required this.timeLabel,
    required this.onMenu,
    this.blurEnabled = true,
    this.scale = 1,
  });

  final String title;
  final String subtitle;
  final Environment env;
  final String timeLabel;

  /// The menu button opens the sessions drawer; without it (desktop layout,
  /// where the sessions panel is always open) there is no button.
  final VoidCallback? onMenu;
  final bool blurEnabled;

  /// Text size factor on very wide windows (see uiScaleFor); 1 elsewhere.
  final double scale;

  @override
  Widget build(BuildContext context) {
    final style = glassFor(env.dayness);
    return GlassPanel(
      style: style,
      blurEnabled: blurEnabled,
      radius: Radii.sheet,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.x3,
        vertical: Space.x3,
      ),
      child: Builder(
        builder: (context) {
          // Read the style as the panel animates it, so the text fades with the tint.
          final s = GlassScope.maybeOf(context) ?? style;
          return Row(
            children: [
              if (onMenu != null) ...[
                Semantics(
                  label: 'Sessions',
                  button: true,
                  child: IconButton(
                    tooltip: 'Sessions',
                    constraints: const BoxConstraints(
                      minWidth: minTap,
                      minHeight: minTap,
                    ),
                    onPressed: onMenu,
                    icon: Icon(Icons.menu_rounded, color: s.ink),
                  ),
                ),
                const SizedBox(width: Space.x2),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18 * scale,
                        fontWeight: FontWeight.w700,
                        color: s.ink,
                      ),
                    ),
                    const SizedBox(height: Space.x1),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5 * scale,
                        color: s.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.x2),
              SunArc(env: env, timeLabel: timeLabel),
            ],
          );
        },
      ),
    );
  }
}
