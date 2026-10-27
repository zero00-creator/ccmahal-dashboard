import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;

import '../models.dart';
import '../sprites.dart';
import '../theme/tokens.dart';
import 'glass.dart';
import 'status.dart';

/// One skin drawn small, as the crab's face in a list.
class CrabIcon extends StatelessWidget {
  const CrabIcon({super.key, required this.skin, this.size = 44});

  final Skin skin;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _CrabIconPainter(skin)),
  );
}

class _CrabIconPainter extends CustomPainter {
  _CrabIconPainter(this.skin);
  final Skin skin;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / skinWidth;
    final top = (size.height - skinHeight * s) / 2;
    final paint = Paint()..isAntiAlias = false;
    for (final p in skin.pixels) {
      paint.color = p.color;
      canvas.drawRect(
        Rect.fromLTWH(p.x * s, top + p.y * s, p.w * s + 0.5, p.h * s + 0.5),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_CrabIconPainter old) => old.skin != skin;
}

/// One agent: its crab, what it does, its progress, context and cost.
class AgentTile extends StatelessWidget {
  const AgentTile({
    super.key,
    required this.agent,
    required this.sprites,
    required this.style,
  });

  final AgentInfo agent;
  final SpriteSet sprites;
  final GlassStyle style;

  @override
  Widget build(BuildContext context) {
    final a = agent;
    final failed = a.status == 'failed';
    final finished = a.status == 'done';
    final total = a.stepTotal ?? 0;
    final meta = ['ctx ${a.ctxPct ?? '-'}%', money(a.costUsd)].join('  ·  ');
    return Opacity(
      opacity: finished ? 0.6 : 1,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.symmetric(
          horizontal: Space.x4,
          vertical: Space.x2,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CrabIcon(skin: sprites.forType(a.type)),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${a.type} · ${a.task}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: failed ? statusColor('failed') : style.ink,
                    ),
                  ),
                  if (a.stepNote.isNotEmpty)
                    Text(
                      a.stepNote,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.5, color: style.inkMuted),
                    ),
                  if (total > 0) ...[
                    const SizedBox(height: Space.x1),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: ((a.stepDone ?? 0) / total).clamp(0.0, 1.0),
                        minHeight: 5,
                        color: failed
                            ? statusColor('failed')
                            : statusColor(a.isRunning ? 'running' : 'idle'),
                        backgroundColor: style.inkMuted.withValues(alpha: 0.2),
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    meta,
                    style: TextStyle(fontSize: 11.5, color: style.inkMuted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _tile(AgentInfo a, SpriteSet sprites, GlassStyle style) => KeyedSubtree(
  key: ValueKey('coworker-${a.id}'),
  child: AgentTile(agent: a, sprites: sprites, style: style),
);

/// The heading, the empty note and one tile per agent: shared by the phone's
/// sheet and the desktop panel.
List<Widget> _rows(
  List<AgentInfo> agents,
  SpriteSet sprites,
  GlassStyle style,
) => [
  Padding(
    padding: const EdgeInsets.fromLTRB(Space.x4, Space.x1, Space.x4, Space.x1),
    child: Text(
      'Coworkers',
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: style.ink,
      ),
    ),
  ),
  if (agents.isEmpty)
    Padding(
      padding: const EdgeInsets.all(Space.x4),
      child: Text(
        'No agents in this session yet.',
        style: TextStyle(color: style.inkMuted),
      ),
    ),
  for (final a in agents) _tile(a, sprites, style),
];

/// The glass sheet over the office: collapsed it shows the first two agents,
/// dragged up it shows them all.
class CoworkersSheet extends StatelessWidget {
  const CoworkersSheet({
    super.key,
    required this.agents,
    required this.sprites,
    required this.style,
    this.blurEnabled = true,
  });

  final List<AgentInfo> agents;
  final SpriteSet sprites;
  final GlassStyle style;
  final bool blurEnabled;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.22,
      minChildSize: 0.12,
      maxChildSize: 0.7,
      builder: (context, controller) => GlassPanel(
        style: style,
        blurEnabled: blurEnabled,
        radius: Radii.sheet,
        child: ListView(
          controller: controller,
          padding: const EdgeInsets.only(bottom: Space.x4),
          scrollCacheExtent: const ScrollCacheExtent.pixels(0),
          children: [
            Center(
              child: Container(
                key: const ValueKey('sheet-handle'),
                margin: const EdgeInsets.only(top: Space.x2),
                width: 48,
                height: 20,
                alignment: Alignment.center,
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: style.inkMuted.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            ..._rows(agents, sprites, style),
          ],
        ),
      ),
    );
  }
}

/// The desktop layout's coworkers list: the same rows as the sheet on a glass
/// panel that fills the space it is given (no dragging, no handle).
class CoworkersPanel extends StatelessWidget {
  const CoworkersPanel({
    super.key,
    required this.agents,
    required this.sprites,
    required this.style,
    this.blurEnabled = true,
  });

  final List<AgentInfo> agents;
  final SpriteSet sprites;
  final GlassStyle style;
  final bool blurEnabled;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      style: style,
      blurEnabled: blurEnabled,
      radius: Radii.sheet,
      child: ListView(
        padding: const EdgeInsets.only(top: Space.x3, bottom: Space.x4),
        children: _rows(agents, sprites, style),
      ),
    );
  }
}

/// The Agents tab: every agent of the selected session.
class AgentsList extends StatelessWidget {
  const AgentsList({
    super.key,
    required this.agents,
    required this.sprites,
    required this.style,
  });

  final List<AgentInfo> agents;
  final SpriteSet sprites;
  final GlassStyle style;

  @override
  Widget build(BuildContext context) {
    if (agents.isEmpty) {
      return Center(
        child: Text(
          'No agents in this session yet.',
          style: TextStyle(color: style.ink),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: Space.x3),
      children: [for (final a in agents) _tile(a, sprites, style)],
    );
  }
}
