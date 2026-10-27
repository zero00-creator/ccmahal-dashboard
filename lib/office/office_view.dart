import 'dart:async';

import 'package:flutter/material.dart';

import '../environment.dart';
import '../models.dart';
import '../sprites.dart';
import '../theme/motion.dart';
import '../theme/tokens.dart';
import '../ui/glass.dart';
import 'iso_painter.dart';
import 'layout.dart';

/// The wide hall is drawn when the area is at least this wide for its height
/// (a phone in portrait stays compact; the desktop centre column is wide).
const wideSceneMinAspect = 1.0;

/// Which room fits an area of [size]: the wide hall when it is wide enough,
/// else the compact room (also when the area has no bounded size).
SceneKind sceneKindForSize(Size size) {
  if (!size.width.isFinite || !size.height.isFinite || size.height <= 0) {
    return SceneKind.compact;
  }
  return size.width / size.height >= wideSceneMinAspect
      ? SceneKind.wide
      : SceneKind.compact;
}

/// The animated isometric office for one session. With animations turned
/// off in the system the scene is drawn once, still. Tapping a crab shows
/// its name and status for a few seconds.
class OfficeView extends StatefulWidget {
  const OfficeView({
    super.key,
    required this.session,
    required this.sprites,
    required this.env,
    required this.serverNow,
    this.debugOnPaint,
    this.onTarget,
  });

  /// When set, tapping a crab reports its target ('main' or the agent type)
  /// instead of showing the small status chip.
  final ValueChanged<String>? onTarget;

  final SessionInfo session;
  final SpriteSet sprites;
  final Environment env;
  final int serverNow;

  /// Called once per paint; tests count repaints with it.
  final VoidCallback? debugOnPaint;

  @override
  State<OfficeView> createState() => _OfficeViewState();
}

class _OfficeViewState extends State<OfficeView> {
  /// The animations step at most 12 times a second, so the room repaints at that rate and not at the screen's.
  static const _frame = Duration(milliseconds: 84);
  static const _chipFor = Duration(seconds: 4);
  final ValueNotifier<int> _ticks = ValueNotifier(0);
  Timer? _timer;
  Timer? _chipTimer;
  final Stopwatch _clock = Stopwatch()..start();
  final _seatsCompact = SeatAssigner(SceneKind.compact);
  final _seatsWide = SeatAssigner(SceneKind.wide);
  Seat? _chipSeat;
  Offset? _chipAt;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final still = Motion.scaled(context, Motion.standard) == Duration.zero;
    if (still) {
      _timer?.cancel();
      _timer = null;
    } else {
      _timer ??= Timer.periodic(_frame, (_) => _ticks.value++);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _chipTimer?.cancel();
    _ticks.dispose();
    super.dispose();
  }

  void _hideChip() {
    _chipTimer?.cancel();
    if (_chipSeat != null) setState(() => _chipSeat = _chipAt = null);
  }

  void _tap(IsoOfficePainter painter, Offset local, Size size) {
    final seat = painter.seatAt(local, size);
    if (seat == null) {
      _hideChip();
      return;
    }
    if (widget.onTarget != null) {
      widget.onTarget!(seat.agent?.type ?? 'main');
      return;
    }
    final g = painter.geometry(size);
    final i = painter.plan!.seats.indexOf(seat);
    _chipTimer?.cancel();
    setState(() {
      _chipSeat = seat;
      _chipAt = g.seatPoints[i] - Offset(0, 36 * g.scale);
    });
    _chipTimer = Timer(_chipFor, _hideChip);
  }

  String _statusLine(Seat seat) {
    final a = seat.agent;
    if (a == null) {
      final live = widget.session.liveStatus(widget.serverNow);
      return widget.session.pending > 0 ? 'waiting for you' : live;
    }
    return [a.status, if (a.stepNote.isNotEmpty) a.stepNote].join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: LayoutBuilder(
        builder: (context, outer) {
          final kind = sceneKindForSize(outer.biggest);
          final scene = _scene(context, kind);
          // The wide hall fills the whole area; the compact room keeps its shape.
          return kind == SceneKind.wide
              ? SizedBox(
                  width: outer.maxWidth,
                  height: outer.maxHeight,
                  child: scene,
                )
              : AspectRatio(aspectRatio: sceneW / sceneH, child: scene);
        },
      ),
    );
  }

  Widget _scene(BuildContext context, SceneKind kind) {
    final still = Motion.scaled(context, Motion.standard) == Duration.zero;
    final plan = (kind == SceneKind.wide ? _seatsWide : _seatsCompact).plan(
      widget.session.agents,
    );
    final painter = IsoOfficePainter(
      session: widget.session,
      sprites: widget.sprites,
      env: widget.env,
      clock: () {
        widget.debugOnPaint?.call();
        return still ? 0.0 : _clock.elapsedMilliseconds / 1000.0;
      },
      serverNow: widget.serverNow,
      plan: plan,
      scene: kind,
      repaint: _ticks,
    );
    final style = glassFor(widget.env.dayness);
    final title = widget.session.title.isNotEmpty
        ? widget.session.title
        : widget.session.project;
    return LayoutBuilder(
      builder: (context, box) {
        final size = box.biggest;
        return Semantics(
          label:
              'Office of $title, ${widget.session.agents.where((a) => a.isRunning).length} agents working',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _tap(painter, d.localPosition, size),
            child: Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: painter)),
                if (_chipSeat != null && _chipAt != null)
                  Positioned(
                    left: (_chipAt!.dx - 80).clamp(4.0, size.width - 164),
                    top: (_chipAt!.dy - 30).clamp(4.0, size.height - 60),
                    width: 160,
                    child: GlassPanel(
                      key: const ValueKey('crab-chip'),
                      style: style,
                      blurEnabled: false,
                      radius: Radii.chip,
                      padding: const EdgeInsets.symmetric(
                        horizontal: Space.x3,
                        vertical: Space.x2,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _chipSeat!.agent?.type ?? 'main',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: style.ink,
                            ),
                          ),
                          Text(
                            _statusLine(_chipSeat!),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: style.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
