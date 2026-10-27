import 'package:flutter/material.dart';

import '../environment.dart';
import '../models.dart';
import '../theme/tokens.dart';
import 'glass.dart';
import 'status.dart';

/// "seen 12s ago", "seen 5m ago", "seen 3h ago", or "ended". Null when the
/// session has no last-seen time.
String? seenLabel(SessionInfo s, int serverNow) {
  if (s.status == 'ended') return 'ended';
  if (s.seenAt <= 0) return null;
  final sec = ((serverNow - s.seenAt) / 1000).floor().clamp(0, 1 << 30);
  if (sec < 60) return 'seen ${sec}s ago';
  if (sec < 3600) return 'seen ${sec ~/ 60}m ago';
  if (sec < 86400) return 'seen ${sec ~/ 3600}h ago';
  return 'seen ${sec ~/ 86400}d ago';
}

/// A thin glass strip along the top of the desktop centre column: agents
/// working out of all, session cost, context fill and last seen. It only
/// shows; a value the session does not have is left out.
class StatsStrip extends StatelessWidget {
  const StatsStrip({
    super.key,
    required this.session,
    required this.serverNow,
    required this.env,
    this.scale = 1,
  });

  final SessionInfo session;
  final int serverNow;
  final Environment env;

  /// Text size factor on very wide windows (see uiScaleFor).
  final double scale;

  @override
  Widget build(BuildContext context) {
    final style = glassFor(env.dayness);
    final total = session.agents.length;
    final working = session.agents.where((a) => a.isRunning).length;
    final seen = seenLabel(session, serverNow);
    if (total == 0 &&
        session.costUsd == null &&
        session.ctxPct == null &&
        seen == null) {
      return const SizedBox.shrink();
    }
    return GlassPanel(
      style: style,
      blurEnabled: false,
      radius: Radii.chip,
      padding: EdgeInsets.symmetric(
        horizontal: Space.x3,
        vertical: Space.x1 + 2 * scale,
      ),
      child: Builder(
        builder: (context) {
          final s = GlassScope.maybeOf(context) ?? style;
          Widget stat(String key, String text, {bool strong = false}) => Text(
            text,
            key: ValueKey(key),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12.5 * scale,
              fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              color: strong ? s.ink : s.inkMuted,
            ),
          );
          final items = <Widget>[
            if (total > 0)
              stat('stat-agents', '$working/$total working', strong: true),
            if (session.costUsd != null)
              stat('stat-cost', money(session.costUsd)),
            if (session.ctxPct != null)
              stat('stat-ctx', 'context ${session.ctxPct}%'),
            if (seen != null) stat('stat-seen', seen),
          ];
          return Semantics(
            container: true,
            label: 'Session numbers',
            child: Wrap(
              alignment: WrapAlignment.spaceEvenly,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: Space.x5 * scale,
              runSpacing: Space.x1,
              children: items,
            ),
          );
        },
      ),
    );
  }
}
