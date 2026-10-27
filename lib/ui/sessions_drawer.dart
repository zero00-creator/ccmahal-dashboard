import 'package:flutter/material.dart';

import '../models.dart';
import '../sprites.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import 'coworkers.dart';
import 'glass.dart';
import 'status.dart';

/// The left panel as a drawer: the sessions panel in a [Drawer].
class SessionsDrawer extends StatelessWidget {
  const SessionsDrawer({
    super.key,
    required this.sessions,
    required this.selectedKey,
    required this.serverNow,
    required this.onSelect,
    required this.style,
    required this.sprites,
    this.blurEnabled = true,
    this.onSignOut,
  });

  final List<SessionInfo> sessions;
  final String? selectedKey;
  final int serverNow;
  final ValueChanged<String> onSelect;
  final GlassStyle style;
  final SpriteSet sprites;
  final bool blurEnabled;

  /// When given, the panel ends with a sign-out button.
  final VoidCallback? onSignOut;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: Colors.transparent,
      elevation: 0,
      width: 320,
      child: SessionsPanel(
        sessions: sessions,
        selectedKey: selectedKey,
        serverNow: serverNow,
        onSelect: onSelect,
        style: style,
        sprites: sprites,
        blurEnabled: blurEnabled,
        onSignOut: onSignOut,
      ),
    );
  }
}

/// The sessions in a fixed order on a glass panel. Tap a row to select it.
/// The phone shows it in a drawer, the desktop layout keeps it open.
class SessionsPanel extends StatelessWidget {
  const SessionsPanel({
    super.key,
    required this.sessions,
    required this.selectedKey,
    required this.serverNow,
    required this.onSelect,
    required this.style,
    required this.sprites,
    this.blurEnabled = true,
    this.onSignOut,
    this.outerPadding = const EdgeInsets.fromLTRB(
      Space.x2,
      Space.x6,
      Space.x2,
      Space.x4,
    ),
  });

  final List<SessionInfo> sessions;
  final String? selectedKey;
  final int serverNow;
  final ValueChanged<String> onSelect;
  final GlassStyle style;
  final SpriteSet sprites;
  final bool blurEnabled;

  /// When given, the panel ends with a sign-out button.
  final VoidCallback? onSignOut;

  /// Space around the glass; the drawer leaves more room at the top.
  final EdgeInsetsGeometry outerPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: outerPadding,
      child: GlassPanel(
        style: style,
        blurEnabled: blurEnabled,
        radius: Radii.sheet,
        padding: const EdgeInsets.symmetric(vertical: Space.x4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.x4),
              child: Text(
                'Sessions',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: style.ink,
                ),
              ),
            ),
            const SizedBox(height: Space.x3),
            Expanded(
              child: ListView(
                children: [
                  for (final s in sessions)
                    _Row(
                      key: ValueKey('row-${s.key}'),
                      session: s,
                      selected: s.key == selectedKey,
                      serverNow: serverNow,
                      style: style,
                      sprites: sprites,
                      onTap: () => onSelect(s.key),
                    ),
                ],
              ),
            ),
            if (onSignOut != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: Space.x2),
                child: TextButton.icon(
                  key: const ValueKey('sign-out'),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(minTap),
                    foregroundColor: style.inkMuted,
                    alignment: Alignment.centerLeft,
                  ),
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Sign out'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.session,
    required this.selected,
    required this.serverNow,
    required this.style,
    required this.sprites,
    required this.onTap,
  });

  final SessionInfo session;
  final bool selected;
  final int serverNow;
  final GlassStyle style;
  final SpriteSet sprites;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = session;
    final working = s.agents.where((a) => a.isRunning).length;
    final summary = [
      working > 0 ? '$working working' : 'idle',
      if (s.costUsd != null) money(s.costUsd),
    ].join('  ·  ');
    final live = s.liveStatus(serverNow);
    final dim = live == 'offline';
    return Opacity(
      key: ValueKey('row-opacity-${s.key}'),
      opacity: dim ? 0.55 : 1,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: minTap),
          margin: const EdgeInsets.symmetric(
            horizontal: Space.x2,
            vertical: Space.x1,
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: Space.x3,
            vertical: Space.x3,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.chip + 6),
            border: Border.all(
              color: selected ? style.accent : Colors.transparent,
              width: 1.5,
            ),
            color: selected
                ? style.accent.withValues(alpha: 0.12)
                : Colors.transparent,
          ),
          child: Row(
            children: [
              CrabIcon(skin: sprites.main, size: 36),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.project,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: style.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      summary,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: style.inkMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Space.x2),
              _StatusDot(
                color: statusColor(live),
                pulse: s.pending > 0 && !dim,
              ),
              const SizedBox(width: Space.x2),
              Text(
                live,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: style.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A status light; it pulses only while a question waits for you.
class _StatusDot extends StatefulWidget {
  const _StatusDot({required this.color, required this.pulse});
  final Color color;
  final bool pulse;

  @override
  State<_StatusDot> createState() => _StatusDotState();
}

class _StatusDotState extends State<_StatusDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = Motion.scaled(context, Motion.standard) == Duration.zero;
    if (widget.pulse && !still) {
      if (!_c.isAnimating) _c.repeat(reverse: true);
    } else {
      _c.stop();
      _c.value = 1;
    }
  }

  @override
  void didUpdateWidget(_StatusDot old) {
    super.didUpdateWidget(old);
    didChangeDependencies();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1).animate(_c),
      child: Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
      ),
    );
  }
}
