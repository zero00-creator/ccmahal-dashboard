import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../environment.dart';
import '../models.dart';
import '../sprites.dart';
import 'iso.dart';
import 'layout.dart';
import 'mood.dart';
import 'palette.dart';

/// The compact scene (phone) is laid out on a grid of cells, 260 wide and 450
/// tall, scaled to fit. The wide hall (desktop centre column) is 384 x 297.
const sceneW = 260.0;
const sceneH = 450.0;
const wideSceneW = 384.0;
const wideSceneH = 297.0;

/// One window in a wall. `u` runs along the wall (gy on the left wall, gx on
/// the right wall).
class WinSpec {
  const WinSpec({
    required this.onRight,
    required this.g0,
    required this.g1,
    required this.z0,
    required this.z1,
    required this.buildings,
    required this.stars,
    required this.seed,
    this.sun,
  });
  final bool onRight;
  final double g0, g1, z0, z1;

  /// Skyline: (start along the wall, height).
  final List<(double, double)> buildings;
  final int stars;
  final int seed;

  /// The sun, moon and cloud cross this window; null for plain windows.
  final SunSpec? sun;
}

class SunSpec {
  const SunSpec({
    required this.arcFrom,
    required this.arcSpan,
    required this.arcZ0,
    required this.arcAmp,
    required this.cloudFrom,
    required this.cloudSpan,
    required this.cloudZ,
  });
  final double arcFrom, arcSpan, arcZ0, arcAmp;
  final double cloudFrom, cloudSpan, cloudZ;
}

/// Everything that differs between the compact room and the wide hall.
class SceneSpec {
  const SceneSpec({
    required this.w,
    required this.h,
    required this.iso,
    required this.nx,
    required this.ny,
    required this.wallH,
    required this.shadowAt,
    required this.shadowW,
    required this.shadowH,
    required this.rugOuter,
    required this.rugInner,
    required this.windows,
    required this.board,
    required this.boardK,
    required this.signGx,
    required this.signScale,
    required this.shaft,
    required this.overflowAt,
    required this.windowCenter,
    required this.boardCenter,
  });
  final double w, h;
  final IsoProjection iso;

  /// Room size in tiles: nx along the right wall, ny along the left wall.
  final double nx, ny;
  final double wallH;
  final (double, double) shadowAt;
  final double shadowW, shadowH;
  final (double, double, double, double) rugOuter, rugInner;
  final List<WinSpec> windows;

  /// The framed board: gx0, gx1, z0, z1.
  final (double, double, double, double) board;

  /// Board text positions and sizes are for the compact board; this scales them.
  final double boardK;
  final double signGx, signScale;

  /// The four floor points of the light shaft: (gx, gy).
  final List<(double, double)> shaft;

  /// Where "+n more" goes, in cells.
  final Offset overflowAt;
  final (double, double, double) windowCenter, boardCenter;
}

const _compactSpec = SceneSpec(
  w: sceneW,
  h: sceneH,
  iso: IsoProjection(tileW: 28, tileH: 14, origin: Offset(130, 150)),
  nx: 8,
  ny: 8,
  wallH: 66,
  shadowAt: (4, 4),
  shadowW: 215,
  shadowH: 44,
  rugOuter: (2.6, 2.0, 6.8, 6.4),
  rugInner: (2.9, 2.3, 6.5, 6.1),
  windows: [
    WinSpec(
      onRight: false,
      g0: 1.4,
      g1: 5.8,
      z0: 28,
      z1: 58,
      buildings: [
        (1.5, 9.0),
        (2.1, 14.0),
        (2.8, 7.0),
        (3.4, 16.0),
        (4.2, 10.0),
        (4.9, 13.0),
      ],
      stars: 16,
      seed: 2,
      sun: SunSpec(
        arcFrom: 5.4,
        arcSpan: 3.6,
        arcZ0: 32,
        arcAmp: 22,
        cloudFrom: 2.0,
        cloudSpan: 3.0,
        cloudZ: 51,
      ),
    ),
  ],
  board: (2.4, 6.9, 30, 58),
  boardK: 1,
  signGx: 3.7,
  signScale: 1,
  shaft: [(0, 1.4), (0, 5.8), (3.6, 7.2), (3.6, 2.8)],
  overflowAt: Offset(188, 214),
  windowCenter: (0, 2.3, 55),
  boardCenter: (4.65, 0, 44),
);

const _wideSpec = SceneSpec(
  w: wideSceneW,
  h: wideSceneH,
  iso: IsoProjection(tileW: 28, tileH: 14, origin: Offset(122, 98)),
  nx: 18,
  ny: 8,
  wallH: 88,
  shadowAt: (9, 4),
  shadowW: 330,
  shadowH: 60,
  rugOuter: (3.4, 1.8, 11.0, 7.0),
  rugInner: (3.7, 2.1, 10.7, 6.7),
  windows: [
    WinSpec(
      onRight: false,
      g0: 1.2,
      g1: 6.8,
      z0: 30,
      z1: 66,
      buildings: [
        (1.3, 9.0),
        (1.9, 14.0),
        (2.6, 7.0),
        (3.2, 16.0),
        (4.0, 10.0),
        (4.7, 13.0),
        (5.4, 8.0),
        (6.0, 12.0),
      ],
      stars: 22,
      seed: 2,
      sun: SunSpec(
        arcFrom: 6.4,
        arcSpan: 4.8,
        arcZ0: 36,
        arcAmp: 26,
        cloudFrom: 2.0,
        cloudSpan: 4.4,
        cloudZ: 58,
      ),
    ),
    WinSpec(
      onRight: true,
      g0: 1.0,
      g1: 5.4,
      z0: 30,
      z1: 66,
      buildings: [
        (1.2, 12.0),
        (1.9, 8.0),
        (2.5, 16.0),
        (3.3, 10.0),
        (4.0, 14.0),
        (4.6, 7.0),
      ],
      stars: 14,
      seed: 3,
    ),
    WinSpec(
      onRight: true,
      g0: 12.6,
      g1: 17.0,
      z0: 30,
      z1: 66,
      buildings: [
        (12.8, 9.0),
        (13.5, 15.0),
        (14.2, 8.0),
        (14.9, 13.0),
        (15.7, 10.0),
        (16.3, 16.0),
      ],
      stars: 14,
      seed: 4,
    ),
  ],
  board: (6.4, 11.6, 32, 68),
  boardK: 1.25,
  signGx: 6.0,
  signScale: 2,
  shaft: [(0, 1.2), (0, 6.8), (4.6, 8.2), (4.6, 2.6)],
  overflowAt: Offset(238, 242),
  windowCenter: (0, 2.3, 62),
  boardCenter: (9.0, 0, 50),
);

SceneSpec specOf(SceneKind kind) =>
    kind == SceneKind.wide ? _wideSpec : _compactSpec;

/// 5 x 7 letters for the brass sign.
const _glyphs = <String, List<String>>{
  'C': ['01110', '10001', '10000', '10000', '10000', '10001', '01110'],
  'm': ['00000', '00000', '11010', '10101', '10101', '10101', '10101'],
  'a': ['00000', '00000', '01110', '00001', '01111', '10001', '01111'],
  'h': ['10000', '10000', '10110', '11001', '10001', '10001', '10001'],
  'l': ['01100', '00100', '00100', '00100', '00100', '00100', '01110'],
};

/// Where things are, in canvas pixels, so tests and overlays can find them.
class RoomGeometry {
  const RoomGeometry({
    required this.scale,
    required this.windowCenter,
    required this.boardCenter,
    required this.lamps,
    required this.seatPoints,
  });
  final double scale;
  final Offset windowCenter;
  final Offset boardCenter;
  final List<Offset> lamps;
  final List<Offset> seatPoints;
}

class IsoOfficePainter extends CustomPainter {
  IsoOfficePainter({
    required this.session,
    required this.sprites,
    required this.env,
    required this.clock,
    required this.serverNow,
    this.plan,
    this.scene = SceneKind.compact,
    super.repaint,
  }) : _spec = specOf(scene);

  /// Which room is drawn.
  final SceneKind scene;
  final SceneSpec _spec;

  final SessionInfo session;
  final SpriteSet sprites;
  final Environment env;

  /// Seconds since the scene started. Every animation reads it; nothing else.
  final double Function() clock;
  final int serverNow;

  /// Who sits where. The view keeps one assigner so desks stay put; without it every agent is a newcomer.
  final SeatPlan? plan;

  final Paint _p = Paint()..isAntiAlias = false;

  IsoProjection get _iso => _spec.iso;

  late double _s;
  late Offset _o;

  Offset _px(Offset cell) => Offset(_o.dx + cell.dx * _s, _o.dy + cell.dy * _s);
  Offset _pt(double gx, double gy, [double z = 0]) =>
      _px(_iso.toScreen(gx, gy, z));

  void _setup(Size size) {
    _s = math.min(size.width / _spec.w, size.height / _spec.h);
    _o = Offset(
      (size.width - _spec.w * _s) / 2,
      (size.height - _spec.h * _s) / 2,
    );
  }

  /// Desk and lamp positions follow the seat plan.
  SeatPlan get _plan => plan ?? planSeats(session.agents, scene);
  List<Seat> get _seats => _plan.seats;

  RoomGeometry geometry(Size size) {
    _setup(size);
    final seats = _seats;
    return RoomGeometry(
      scale: _s,
      // a point in open sky, clear of the mullions and the sun
      windowCenter: _pt(
        _spec.windowCenter.$1,
        _spec.windowCenter.$2,
        _spec.windowCenter.$3,
      ),
      boardCenter: _pt(
        _spec.boardCenter.$1,
        _spec.boardCenter.$2,
        _spec.boardCenter.$3,
      ),
      lamps: [for (final s in seats) _pt(s.gx + 0.7, s.gy + 0.2, 15)],
      seatPoints: [for (final s in seats) _pt(s.gx + 0.2, s.gy + 0.65, 0)],
    );
  }

  /// The seat whose crab is under [local] (canvas pixels), or null on empty floor.
  Seat? seatAt(Offset local, Size size) {
    final g = geometry(size);
    final seats = _seats;
    Seat? best;
    var bestD = double.infinity;
    for (var i = 0; i < seats.length; i++) {
      // A crab is 28 cells tall and stands on its seat point: its middle is half that above.
      final c = g.seatPoints[i] - Offset(0, 14 * g.scale);
      final dx = (local.dx - c.dx).abs();
      final dy = (local.dy - c.dy).abs();
      if (dx <= 16 * g.scale && dy <= 16 * g.scale) {
        final d = dx * dx + dy * dy;
        if (d < bestD) {
          best = seats[i];
          bestD = d;
        }
      }
    }
    return best;
  }

  // -- low-level drawing in cells --------------------------------------------

  void _rect(Canvas c, double x, double y, double w, double h, Color color) {
    _p.color = color;
    c.drawRect(
      Rect.fromLTRB(
        (_o.dx + x * _s).floorToDouble(),
        (_o.dy + y * _s).floorToDouble(),
        (_o.dx + (x + w) * _s).ceilToDouble(),
        (_o.dy + (y + h) * _s).ceilToDouble(),
      ),
      _p,
    );
  }

  void _poly(Canvas c, List<(double, double, double)> pts, Color color) {
    final path = Path();
    for (var i = 0; i < pts.length; i++) {
      final p = _pt(pts[i].$1, pts[i].$2, pts[i].$3);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    _p.color = color;
    c.drawPath(path, _p);
  }

  Color _shade(Color c, double f) => Color.from(
    alpha: c.a,
    red: (c.r * f).clamp(0.0, 1.0),
    green: (c.g * f).clamp(0.0, 1.0),
    blue: (c.b * f).clamp(0.0, 1.0),
  );

  // -- the room ---------------------------------------------------------------

  void _background(Canvas c, Size size) {
    final top = Color.lerp(
      const Color(0xFF141936),
      const Color(0xFFF6E7C8),
      env.dayness,
    )!;
    final bottom = Color.lerp(
      const Color(0xFF2A2548),
      const Color(0xFFD9B98A),
      env.dayness,
    )!;
    c.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [top, bottom],
        ).createShader(Offset.zero & size),
    );
    // a soft shadow under the room block
    final shadow = Paint()
      ..color = const Color(0x40000000)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * _s);
    c.drawOval(
      Rect.fromCenter(
        center: _pt(_spec.shadowAt.$1, _spec.shadowAt.$2, -9),
        width: _spec.shadowW * _s,
        height: _spec.shadowH * _s,
      ),
      shadow,
    );
  }

  void _floor(Canvas c) {
    final f1 = env.floor;
    final f2 = _shade(env.floor, 0.93);
    final nx = _spec.nx, ny = _spec.ny;
    for (var gx = 0; gx < nx; gx++) {
      for (var gy = 0; gy < ny; gy++) {
        _poly(c, [
          (gx + 0.0, gy + 0.0, 0),
          (gx + 1.0, gy + 0.0, 0),
          (gx + 1.0, gy + 1.0, 0),
          (gx + 0.0, gy + 1.0, 0),
        ], (gx + gy).isEven ? f1 : f2);
      }
    }
    final rug = Color.lerp(env.floor, Palette.rug, 0.65)!;
    final ro = _spec.rugOuter, ri = _spec.rugInner;
    _poly(c, [
      (ro.$1, ro.$2, 0),
      (ro.$3, ro.$2, 0),
      (ro.$3, ro.$4, 0),
      (ro.$1, ro.$4, 0),
    ], rug);
    _poly(c, [
      (ri.$1, ri.$2, 0),
      (ri.$3, ri.$2, 0),
      (ri.$3, ri.$4, 0),
      (ri.$1, ri.$4, 0),
    ], Color.lerp(env.floor, Palette.rugInner, 0.55)!);
    // the slab's thickness
    final edge = _shade(env.floor, 0.55);
    _poly(c, [(0, ny, 0), (nx, ny, 0), (nx, ny, -7), (0, ny, -7)], edge);
    _poly(c, [
      (nx, 0, 0),
      (nx, ny, 0),
      (nx, ny, -7),
      (nx, 0, -7),
    ], _shade(env.floor, 0.7));
  }

  void _walls(Canvas c) {
    final left = _shade(env.wall, 0.8);
    final right = env.wall;
    final nx = _spec.nx, ny = _spec.ny, wallH = _spec.wallH;
    _poly(c, [(0, 0, wallH), (0, ny, wallH), (0, ny, 0), (0, 0, 0)], left);
    _poly(c, [(0, 0, wallH), (nx, 0, wallH), (nx, 0, 0), (0, 0, 0)], right);
    _poly(c, [
      (0, 0, 22),
      (0, ny, 22),
      (0, ny, 0),
      (0, 0, 0),
    ], _shade(left, 0.9));
    _poly(c, [
      (0, 0, 22),
      (nx, 0, 22),
      (nx, 0, 0),
      (0, 0, 0),
    ], _shade(right, 0.92));
    _poly(c, [
      (0, 0, 24),
      (0, ny, 24),
      (0, ny, 22),
      (0, 0, 22),
    ], _shade(left, 0.7));
    _poly(c, [
      (0, 0, 24),
      (nx, 0, 24),
      (nx, 0, 22),
      (0, 0, 22),
    ], _shade(right, 0.74));
    for (var k = 1; k < ny; k++) {
      _poly(c, [
        (0, k + 0.0, wallH),
        (0, k + 0.12, wallH),
        (0, k + 0.12, 24),
        (0, k + 0.0, 24),
      ], _shade(left, 0.93));
    }
    for (var k = 1; k < nx; k++) {
      _poly(c, [
        (k + 0.0, 0, wallH),
        (k + 0.12, 0, wallH),
        (k + 0.12, 0, 24),
        (k + 0.0, 0, 24),
      ], _shade(right, 0.95));
    }
  }

  void _windows(Canvas c, double t) {
    for (final w in _spec.windows) {
      _window(c, t, w);
    }
  }

  void _window(Canvas c, double t, WinSpec w) {
    final g0 = w.g0, g1 = w.g1, z0 = w.z0, z1 = w.z1;
    // A point on the wall: u along it, z up.
    (double, double, double) p(double u, double z) =>
        w.onRight ? (u, 0.0, z) : (0.0, u, z);
    void quad(double ua, double ub, double za, double zb, Color col) {
      _poly(c, [p(ua, zb), p(ub, zb), p(ub, za), p(ua, za)], col);
    }

    for (var z = z0.toInt(); z < z1; z++) {
      final k = (z - z0) / (z1 - z0);
      quad(g0, g1, z + 0.0, z + 1.0, Color.lerp(env.skyBottom, env.skyTop, k)!);
    }
    // stars fade in with the dark
    if (env.dayness < 0.7) {
      final rnd = math.Random(w.seed);
      for (var i = 0; i < w.stars; i++) {
        final gy = g0 + 0.1 + rnd.nextDouble() * (g1 - g0 - 0.2);
        final z = z0 + 12 + rnd.nextDouble() * (z1 - z0 - 14);
        final twinkle = 0.55 + 0.45 * math.sin(t * 1.5 + i);
        final q = p(gy, z);
        final pt = _pt(q.$1, q.$2, q.$3);
        _p.color = Color.fromRGBO(
          255,
          255,
          255,
          (1 - env.dayness / 0.7) * twinkle,
        );
        c.drawRect(
          Rect.fromLTWH(pt.dx, pt.dy, math.max(1, _s), math.max(1, _s)),
          _p,
        );
      }
    }
    // the sun by day, the moon by night, along an arc across the window
    final sun = w.sun;
    if (sun != null) {
      double arcGy(double f) => sun.arcFrom - f * sun.arcSpan;
      double arcZ(double f) => sun.arcZ0 + sun.arcAmp * math.sin(math.pi * f);
      void disc(double gy, double z, double r, Color col) {
        final pts = [
          for (var a = 0; a < 18; a++)
            p(
              gy + r * math.cos(a * math.pi / 9) / 14,
              z + r * math.sin(a * math.pi / 9) * 0.9,
            ),
        ];
        _poly(c, pts, col);
      }

      if (env.dayness > 0.25) {
        final f = env.sun;
        disc(
          arcGy(f),
          arcZ(f),
          7,
          Palette.sunHalo.withValues(alpha: env.dayness),
        );
        disc(arcGy(f), arcZ(f), 5, Palette.sunCore);
        // a cloud drifting slowly
        final drift = (t * 0.02) % 1.0;
        final cg = sun.cloudFrom + drift * sun.cloudSpan;
        quad(
          cg,
          cg + 1.2,
          sun.cloudZ - 2.0,
          sun.cloudZ,
          Colors.white.withValues(alpha: env.dayness),
        );
      } else {
        final f = env.moon;
        disc(arcGy(f), arcZ(f), 6, Palette.moon);
        disc(
          arcGy(f) - 0.14,
          arcZ(f) + 2,
          5,
          Color.lerp(env.skyBottom, env.skyTop, 0.8)!,
        );
      }
    }
    // the skyline
    final sky = Color.lerp(
      Palette.skylineNight,
      Palette.skylineDay,
      env.dayness,
    )!;
    for (final b in w.buildings) {
      quad(b.$1, b.$1 + 0.6, z0, z0 + b.$2, sky);
      if (env.lamps > 0.5) {
        for (var zz = z0 + 3; zz < z0 + b.$2 - 2; zz += 4) {
          quad(b.$1 + 0.15, b.$1 + 0.3, zz, zz + 1, Palette.windowLit);
        }
      }
    }
    // the frame
    final frame = Palette.frame;
    quad(g0 - 0.12, g1 + 0.12, z1, z1 + 2, frame);
    quad(g0 - 0.12, g1 + 0.12, z0 - 2, z0, frame);
    quad(g0 - 0.12, g0, z0 - 2, z1 + 2, frame);
    quad(g1, g1 + 0.12, z0 - 2, z1 + 2, frame);
    final mid = (g0 + g1) / 2;
    quad(mid - 0.06, mid + 0.06, z0, z1, frame);
    final bar = (z0 + z1) / 2 + 1;
    quad(g0, g1, bar - 2, bar, frame);
  }

  /// Draws on the right wall (the plane along gx) with the wall's slant.
  void _onRightWall(Canvas c, double gx, double z, void Function() draw) {
    final at = _pt(gx, 0, z);
    c.save();
    c.translate(at.dx, at.dy);
    final m = Float64List.fromList([
      1,
      0.5,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      1,
    ]);
    c.transform(m);
    draw();
    c.restore();
  }

  TextPainter _text(
    String s,
    double cells,
    Color color, {
    double maxWidthCells = 60,
    FontWeight weight = FontWeight.w800,
  }) {
    return TextPainter(
      text: TextSpan(
        text: s,
        style: TextStyle(
          fontSize: cells * _s,
          color: color,
          fontWeight: weight,
          fontFamily: 'monospace',
          height: 1,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidthCells * _s);
  }

  void _board(Canvas c) {
    final (gx0, gx1, z0, z1) = _spec.board;
    final k = _spec.boardK;
    final maxW = scene == SceneKind.compact ? 60.0 : (gx1 - gx0) * 14 - 3;
    _poly(c, [
      (gx0 - 0.15, 0, z1 + 2),
      (gx1 + 0.15, 0, z1 + 2),
      (gx1 + 0.15, 0, z0 - 2),
      (gx0 - 0.15, 0, z0 - 2),
    ], Palette.frameDark);
    _poly(c, [
      (gx0, 0, z1),
      (gx1, 0, z1),
      (gx1, 0, z0),
      (gx0, 0, z0),
    ], Color.lerp(const Color(0xFFD8D4C4), Palette.board, env.dayness)!);
    final working = session.agents.where((a) => a.isRunning).length;
    final sub = session.pending > 0
        ? '${session.pending} waiting for you'
        : (working > 0
              ? '$working agent${working == 1 ? '' : 's'} working'
              : 'quiet');
    _onRightWall(c, gx0, z1, () {
      final w = (gx1 - gx0) * 14 * _s;
      final head = _text(
        'SESSION',
        6 * k,
        Palette.boardMuted,
        weight: FontWeight.w600,
        maxWidthCells: maxW,
      );
      head.paint(c, Offset((w - head.width) / 2, 2.5 * k * _s));
      final name = _text(
        session.title.isNotEmpty ? session.title : session.project,
        11 * k,
        Palette.boardInk,
        maxWidthCells: maxW,
      );
      name.paint(c, Offset((w - name.width) / 2, 8.5 * k * _s));
      final line = _text(
        sub,
        6.5 * k,
        session.pending > 0 ? Palette.boardAlert : Palette.boardOk,
        weight: FontWeight.w700,
        maxWidthCells: maxW,
      );
      line.paint(c, Offset((w - line.width) / 2, 22 * k * _s));
    });
  }

  void _sign(Canvas c) {
    const word = 'CCmahal';
    final k = _spec.signScale;
    _onRightWall(c, _spec.signGx, _spec.wallH, () {
      void run(double dx, double dy, Color color) {
        var x = 0.0;
        for (final ch in word.split('')) {
          final g = _glyphs[ch]!;
          for (var r = 0; r < 7; r++) {
            for (var q = 0; q < 5; q++) {
              if (g[r][q] != '1') continue;
              _p.color = color;
              c.drawRect(
                Rect.fromLTWH(
                  (x + q + dx) * k * _s,
                  (r + dy) * k * _s,
                  k * _s,
                  k * _s,
                ),
                _p,
              );
            }
          }
          x += 6;
        }
      }

      run(1, 1, Palette.brassDark);
      run(0, 0, Palette.brass);
    });
  }

  // -- desks and crabs ----------------------------------------------------------

  void _box(
    Canvas c,
    double gx,
    double gy,
    double w,
    double d,
    double h,
    Color top,
    Color left,
    Color right,
  ) {
    _poly(c, [
      (gx + w, gy, h),
      (gx + w, gy + d, h),
      (gx + w, gy + d, 0),
      (gx + w, gy, 0),
    ], right);
    _poly(c, [
      (gx, gy + d, h),
      (gx + w, gy + d, h),
      (gx + w, gy + d, 0),
      (gx, gy + d, 0),
    ], left);
    _poly(c, [
      (gx, gy, h),
      (gx + w, gy, h),
      (gx + w, gy + d, h),
      (gx, gy + d, h),
    ], top);
  }

  void _desk(Canvas c, Seat seat) {
    final top = Color.lerp(
      Palette.deskTopNight,
      Palette.deskTopDay,
      env.dayness,
    )!;
    final body = Color.lerp(Palette.deskNight, Palette.deskDay, env.dayness)!;
    _box(
      c,
      seat.gx + 0.55,
      seat.gy,
      1.1,
      1.3,
      11,
      top,
      _shade(body, 0.85),
      body,
    );
    final m = _pt(seat.gx + 0.9, seat.gy + 0.9, 11);
    final mc = Offset((m.dx - _o.dx) / _s, (m.dy - _o.dy) / _s);
    _rect(c, mc.dx - 1, mc.dy - 12, 11, 10, Palette.monitor);
    _rect(
      c,
      mc.dx,
      mc.dy - 11,
      9,
      8,
      Color.lerp(Palette.screenNight, Palette.screenDay, env.dayness)!,
    );
    const lines = [Color(0xFF5BE3A0), Color(0xFF7FB4FF), Color(0xFFF0C060)];
    for (var i = 0; i < 3; i++) {
      _rect(c, mc.dx + 1, mc.dy - 10 + i * 3, 3 + (i % 2) * 3 + 2, 1, lines[i]);
    }
    final l = _pt(seat.gx + 0.7, seat.gy + 0.2, 11);
    final lc = Offset((l.dx - _o.dx) / _s, (l.dy - _o.dy) / _s);
    _rect(c, lc.dx, lc.dy - 2, 1, 2, Palette.lampStem);
    _rect(
      c,
      lc.dx - 4,
      lc.dy - 7,
      8,
      4,
      Color.lerp(Palette.lampOff, Palette.lampOn, env.lamps)!,
    );
  }

  Color _tint(Color col, CrabMood mood, bool night) {
    var c = col;
    if (night)
      c = Color.from(alpha: 1, red: c.r * 0.92, green: c.g * 0.94, blue: c.b);
    final g = c.r * 0.3 + c.g * 0.59 + c.b * 0.11;
    switch (mood) {
      case CrabMood.idle:
        return Color.lerp(
          c,
          Color.from(alpha: 1, red: g, green: g, blue: g),
          0.35,
        )!;
      case CrabMood.done:
        return Color.lerp(
          c,
          Color.from(alpha: 1, red: g, green: g, blue: g),
          0.55,
        )!;
      case CrabMood.failed:
        return Color.lerp(c, Palette.failed, 0.45)!;
      default:
        return c;
    }
  }

  void _crab(Canvas c, Seat seat, CrabMood mood, double t) {
    final skin = seat.agent == null
        ? sprites.main
        : sprites.forType(seat.agent!.type);
    final p = _iso.toScreen(seat.gx + 0.2, seat.gy + 0.65, 0);
    final left = p.dx - skinWidth / 2;
    final top = p.dy - skinHeight - 2;
    final moving = mood == CrabMood.working;
    var shake = 0.0;
    if (mood == CrabMood.failed) shake = (t * 12).floor().isEven ? 1 : -1;
    var hop = 0.0;
    if (mood == CrabMood.waiting) hop = (t * 3).floor().isEven ? -2 : 0;
    if (mood == CrabMood.idle) hop = (t * 0.7).floor().isEven ? 0 : 1;
    final legPhase = (t * 5).floor().isEven;
    final propPhase = (t * 3).floor() % 3;
    final night = env.dayness < 0.5;
    for (final px in skin.pixels) {
      var dy = hop;
      var dx = shake;
      if (px.cls == 'la') {
        dy += moving ? (legPhase ? 0 : -1) : 0;
      } else if (px.cls == 'lb') {
        dy += moving ? (legPhase ? -1 : 0) : 0;
      } else if (px.cls != 'bd' && (moving || mood == CrabMood.waiting)) {
        dy += propPhase == 1 ? -1 : 0;
        dx += propPhase == 2 ? 1 : 0;
      }
      _rect(
        c,
        left + px.x + dx,
        top + px.y + dy,
        px.w.toDouble(),
        px.h.toDouble(),
        _tint(px.color, mood, night),
      );
    }
    // a status light over the head
    final lx = left + 15;
    final ly = top - 5;
    final color = switch (mood) {
      CrabMood.working => Palette.running,
      CrabMood.waiting => Palette.waiting,
      CrabMood.failed => Palette.failed,
      _ => Palette.idle,
    };
    _rect(c, lx - 2, ly - 2, 5, 5, Colors.white.withValues(alpha: 0.85));
    _rect(c, lx - 1, ly - 1, 3, 3, color);
    if (mood == CrabMood.waiting) {
      _rect(c, lx - 8, ly - 17, 17, 13, Palette.waitingEdge);
      _rect(c, lx - 7, ly - 16, 15, 11, Palette.waiting);
      _rect(c, lx - 1, ly - 5, 3, 3, Palette.waiting);
      final q = _text('?', 9, Palette.waitingInk);
      q.paint(c, Offset(_o.dx + (lx - 2.5) * _s, _o.dy + (ly - 15.5) * _s));
    }
    if (mood == CrabMood.idle && seat.agent == null) {
      for (var i = 0; i < 3; i++) {
        final ph = ((t * 0.6) + i / 3) % 1.0;
        final z = _text(
          'z',
          5 + i * 1.5,
          Palette.idle.withValues(alpha: 1 - ph),
          weight: FontWeight.w700,
        );
        z.paint(
          c,
          Offset(
            _o.dx + (left + 22 + ph * 8 + i * 2) * _s,
            _o.dy + (top - 2 - ph * 12) * _s,
          ),
        );
      }
    }
  }

  // -- light ----------------------------------------------------------------------

  void _light(Canvas c, Size size, List<Offset> lamps) {
    if (env.dayness > 0.05) {
      final sh = _spec.shaft;
      final shaft = Path();
      for (var i = 0; i < sh.length; i++) {
        final q = _pt(sh[i].$1, sh[i].$2);
        i == 0 ? shaft.moveTo(q.dx, q.dy) : shaft.lineTo(q.dx, q.dy);
      }
      shaft.close();
      c.drawPath(
        shaft,
        Paint()
          ..color = Color.fromRGBO(255, 244, 190, 0.2 * env.dayness)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * _s),
      );
    }
    if (env.ambient.a > 0)
      c.drawRect(Offset.zero & size, Paint()..color = env.ambient);
    if (env.lamps > 0.02) {
      for (final lamp in lamps) {
        final shader = RadialGradient(
          colors: [
            Palette.lampGlow.withValues(alpha: 0.5 * env.lamps),
            Palette.lampGlow.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: lamp, radius: 34 * _s));
        c.drawCircle(lamp, 34 * _s, Paint()..shader = shader);
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    _setup(size);
    final t = clock();
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    _background(canvas, size);
    _floor(canvas);
    _walls(canvas);
    _windows(canvas, t);
    _board(canvas);
    _sign(canvas);

    final plan = _plan;
    final live = session.liveStatus(serverNow);
    final offline = live == 'offline' || live == 'ended';
    // painter's order: farther desks first
    final items = [for (final s in plan.seats) (s, s.gx + s.gy)]
      ..sort((a, b) => a.$2.compareTo(b.$2));
    for (final (seat, _) in items) {
      final mood = seat.agent == null
          ? mainMoodOf(session, serverNow)
          : moodOf(agentStatus: seat.agent!.status, sessionOffline: offline);
      _crab(canvas, seat, mood, t);
      _desk(canvas, seat);
    }
    if (plan.overflow > 0) {
      final more = _text(
        '+${plan.overflow} more',
        6,
        Palette.idle,
        weight: FontWeight.w700,
      );
      more.paint(
        canvas,
        Offset(
          _o.dx + _spec.overflowAt.dx * _s,
          _o.dy + _spec.overflowAt.dy * _s,
        ),
      );
    }
    _light(canvas, size, geometry(size).lamps);
    canvas.restore();
  }

  @override
  bool shouldRepaint(IsoOfficePainter old) => true;
}
