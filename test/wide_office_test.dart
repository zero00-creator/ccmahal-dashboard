import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ccmahal_dashboard/environment.dart';
import 'package:ccmahal_dashboard/models.dart';
import 'package:ccmahal_dashboard/office/iso_painter.dart';
import 'package:ccmahal_dashboard/office/layout.dart';
import 'package:ccmahal_dashboard/office/office_view.dart';
import 'package:ccmahal_dashboard/sprites.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AgentInfo agent(String id, int startedAt, {String status = 'running'}) =>
    AgentInfo(
      id: id,
      type: 'type-$id',
      task: 't',
      model: 'm',
      status: status,
      startedAt: startedAt,
      costUsd: 0,
      stepNote: '',
    );

SpriteSet loadSprites() =>
    SpriteSet.fromJson(File('assets/sprites.json').readAsStringSync());

SessionInfo sessionOf(int n, {String title = 'Wide hall'}) => SessionInfo(
  key: 'k',
  project: 'p',
  title: title,
  status: 'running',
  model: 'opus',
  mode: 'auto',
  limits: const {},
  agents: [
    for (var i = 0; i < n; i++)
      AgentInfo(
        id: 'a$i',
        type: 'type-$i',
        task: 't',
        model: 'm',
        status: i % 3 == 2 ? 'done' : 'running',
        startedAt: i,
        costUsd: 0,
        stepNote: '',
      ),
  ],
  flowTitle: '',
  allowed: 1,
  you: 0,
  pending: 0,
  denied: 0,
  seenAt: 1000000,
);

void main() {
  group('seat tables', () {
    test(
      'the wide hall gives 16 seats: 1 main plus 15 agents, overflow after',
      () {
        final plan = planSeats([
          for (var i = 0; i < 20; i++) agent('a$i', i),
        ], SceneKind.wide);
        expect(plan.seats, hasLength(16));
        expect(plan.seats.where((s) => s.agent != null), hasLength(15));
        expect(plan.overflow, 5);
        expect(agentDeskCount(SceneKind.wide), 15);
        expect(agentDeskCount(SceneKind.compact), 7);
      },
    );

    test('wide desks are all different and keep inside the 18 x 8 room', () {
      final plan = planSeats([
        for (var i = 0; i < 15; i++) agent('a$i', i),
      ], SceneKind.wide);
      final spots = plan.seats.map((s) => (s.gx, s.gy)).toSet();
      expect(spots, hasLength(16));
      for (final s in plan.seats) {
        expect(s.gx, inInclusiveRange(0.5, 16.5));
        expect(s.gy, inInclusiveRange(0.5, 6.5));
      }
    });

    test('compact table is unchanged', () {
      final plan = planSeats([for (var i = 0; i < 7; i++) agent('a$i', i)]);
      expect((plan.seats.first.gx, plan.seats.first.gy), (4.4, 5.0));
      expect(
        [for (final s in plan.seats.skip(1)) (s.gx, s.gy)],
        [
          (1.0, 0.9),
          (1.0, 2.9),
          (1.0, 4.9),
          (1.0, 6.4),
          (4.4, 1.0),
          (4.4, 3.0),
          (4.4, 6.5),
        ],
      );
    });

    test('wide assignment is stable when the list changes', () {
      final assigner = SeatAssigner(SceneKind.wide);
      Map<String, (double, double)> desks(SeatPlan p) => {
        for (final s in p.seats)
          if (s.agent != null) s.agent!.id: (s.gx, s.gy),
      };
      final first = desks(
        assigner.plan([for (var i = 0; i < 10; i++) agent('a$i', i)]),
      );
      final second = desks(
        assigner.plan([
          for (var i = 3; i < 10; i++)
            agent('a$i', i, status: i.isEven ? 'done' : 'running'),
          agent('late', 99),
        ]),
      );
      for (final id in second.keys.where((k) => k != 'late')) {
        expect(second[id], first[id], reason: id);
      }
    });

    test('wide: running agents come first when the hall is full', () {
      final assigner = SeatAssigner(SceneKind.wide);
      final full = [
        for (var i = 0; i < 15; i++) agent('d$i', i, status: 'done'),
      ];
      assigner.plan(full);
      final after = assigner.plan([...full, agent('fresh', 50)]);
      expect(after.seats.any((s) => s.agent?.id == 'fresh'), isTrue);
      expect(after.seats.any((s) => s.agent?.id == 'd0'), isFalse);
      final late = SeatAssigner(SceneKind.wide);
      late.plan(full);
      final none = late.plan([...full, agent('late', 50, status: 'done')]);
      expect(none.seats.any((s) => s.agent?.id == 'late'), isFalse);
      expect(none.overflow, 1);
    });
  });

  group('scene choice', () {
    test(
      'aspect 1.6 picks the wide scene, a portrait one the compact scene',
      () {
        expect(sceneKindForSize(const Size(1600, 1000)), SceneKind.wide);
        expect(sceneKindForSize(const Size(1280, 800)), SceneKind.wide);
        expect(sceneKindForSize(const Size(390, 844)), SceneKind.compact);
        expect(sceneKindForSize(const Size(400, 800)), SceneKind.compact);
        expect(sceneKindForSize(const Size(900, 1000)), SceneKind.compact);
        expect(
          sceneKindForSize(const Size(double.infinity, 800)),
          SceneKind.compact,
        );
      },
    );

    testWidgets('the view paints the wide scene in a wide area and fills it', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(const Size(1600, 900), 3));
      final painter = _painter(tester);
      expect(painter.scene, SceneKind.wide);
      expect(tester.getSize(find.byType(OfficeView)), const Size(1600, 900));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('the view paints the compact scene in a tall area', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_host(const Size(390, 844), 3));
      expect(_painter(tester).scene, SceneKind.compact);
      final box = tester.getSize(find.byType(OfficeView));
      expect(box.width / box.height, closeTo(sceneW / sceneH, 0.01));
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('wide painter', () {
    testWidgets('paints at 1600x900 with 0, 1, 8 and 20 agents without error', (
      tester,
    ) async {
      await tester.runAsync(() async {
        for (final env in [
          environmentAt(DateTime(2026, 10, 26, 7, 0)),
          environmentAt(DateTime(2026, 10, 26, 12, 0)),
          environmentAt(DateTime(2026, 10, 26, 21, 41)),
        ]) {
          for (final n in [0, 1, 8, 20]) {
            final bytes = await _render(_wide(sessionOf(n), env), 1600, 900);
            expect(bytes.lengthInBytes, 1600 * 900 * 4);
          }
        }
      });
    });

    testWidgets(
      'geometry has 16 seats for 20 agents and every seat is on screen',
      (tester) async {
        final p = _wide(
          sessionOf(20),
          environmentAt(DateTime(2026, 10, 26, 12)),
        );
        const size = Size(1600, 900);
        final g = p.geometry(size);
        expect(g.seatPoints, hasLength(16));
        for (final pt in g.seatPoints) {
          expect(Offset.zero & size, _contains(pt));
        }
        // fills the area: height-limited here, scale is 900 / wide scene height
        expect(g.scale, closeTo(900 / wideSceneH, 0.001));
        for (var i = 0; i < 16; i++) {
          expect(
            p.seatAt(g.seatPoints[i] - Offset(0, 14 * g.scale), size),
            isNotNull,
            reason: 'seat $i',
          );
        }
      },
    );

    testWidgets(
      'the window is brighter at noon than at night in the wide room',
      (tester) async {
        await tester.runAsync(() async {
          final noonP = _wide(
            sessionOf(3),
            environmentAt(DateTime(2026, 10, 26, 12)),
          );
          final nightP = _wide(
            sessionOf(3),
            environmentAt(DateTime(2026, 10, 26, 21, 41)),
          );
          final w = noonP.geometry(const Size(1600, 900)).windowCenter;
          final noon = _lum(await _render(noonP, 1600, 900), w, 1600);
          final night = _lum(await _render(nightP, 1600, 900), w, 1600);
          expect(noon - night, greaterThan(60));
        });
      },
    );

    testWidgets('a lamp glows at night in the wide room', (tester) async {
      await tester.runAsync(() async {
        final p = _wide(
          sessionOf(3),
          environmentAt(DateTime(2026, 10, 26, 21, 41)),
        );
        final lamp = p.geometry(const Size(1600, 900)).lamps.first;
        final away = lamp + const Offset(0, 120);
        final img = await _render(p, 1600, 900);
        expect(_lum(img, lamp, 1600) - _lum(img, away, 1600), greaterThan(10));
      });
    });

    testWidgets('renders one PNG of the wide room for the eye', (tester) async {
      await tester.runAsync(() async {
        final dir = Directory(
          Platform.environment['WIDE_PNG_DIR'] ?? Directory.systemTemp.path,
        );
        for (final (name, hour, n) in [
          ('wide_noon_16', 12, 16),
          ('wide_night_8', 21, 8),
        ]) {
          final p = _wide(
            sessionOf(n, title: 'Refactor the billing service'),
            environmentAt(DateTime(2026, 10, 26, hour, 10)),
          );
          const w = 1600, h = 900;
          final rec = ui.PictureRecorder();
          p.paint(Canvas(rec), const Size(1600, 900));
          final img = await rec.endRecording().toImage(w, h);
          final png = (await img.toByteData(format: ui.ImageByteFormat.png))!;
          File('${dir.path}/$name.png')
              .writeAsBytesSync(png.buffer.asUint8List());
        }
      });
    });
  });

  group('taps in the wide room', () {
    testWidgets('tapping a wide-room crab reports that agent', (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final got = <String>[];
      await tester.pumpWidget(
        _host(const Size(1600, 900), 12, onTarget: got.add),
      );
      final box = tester.getRect(find.byType(OfficeView));
      final p = _painter(tester);
      final g = p.geometry(box.size);
      final plan = planSeats(sessionOf(12).agents, SceneKind.wide);
      expect(g.seatPoints, hasLength(plan.seats.length));
      // the 9th agent seat (index 9 in the plan, 0 is main)
      for (final i in [0, 1, 5, 9, 12]) {
        got.clear();
        await tester.tapAt(
          box.topLeft + g.seatPoints[i] - Offset(0, 14 * g.scale),
        );
        await tester.pump();
        expect(got, [plan.seats[i].agent?.type ?? 'main'], reason: 'seat $i');
      }
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets(
      'tapping a wide-room crab shows the chip when onTarget is off',
      (tester) async {
        tester.view.physicalSize = const Size(1600, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_host(const Size(1600, 900), 4));
        final box = tester.getRect(find.byType(OfficeView));
        final g = _painter(tester).geometry(box.size);
        await tester.tapAt(
          box.topLeft + g.seatPoints[2] - Offset(0, 14 * g.scale),
        );
        await tester.pump();
        expect(find.byKey(const ValueKey('crab-chip')), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        expect(find.byKey(const ValueKey('crab-chip')), findsNothing);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}

Matcher _contains(Offset p) =>
    predicate<Rect>((r) => r.contains(p), 'contains $p');

IsoOfficePainter _wide(SessionInfo s, Environment env) => IsoOfficePainter(
  session: s,
  sprites: loadSprites(),
  env: env,
  clock: () => 1.37,
  serverNow: 1000000,
  scene: SceneKind.wide,
  plan: planSeats(s.agents, SceneKind.wide),
);

Future<ByteData> _render(IsoOfficePainter p, int w, int h) async {
  final rec = ui.PictureRecorder();
  p.paint(Canvas(rec), Size(w.toDouble(), h.toDouble()));
  final img = await rec.endRecording().toImage(w, h);
  return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
}

double _lum(ByteData d, Offset o, int width) {
  final i = ((o.dy.round() * width) + o.dx.round()) * 4;
  return 0.2126 * d.getUint8(i) +
      0.7152 * d.getUint8(i + 1) +
      0.0722 * d.getUint8(i + 2);
}

IsoOfficePainter _painter(WidgetTester tester) {
  final paints = tester.widgetList<CustomPaint>(
    find.descendant(
      of: find.byType(OfficeView),
      matching: find.byType(CustomPaint),
    ),
  );
  return paints.map((c) => c.painter).whereType<IsoOfficePainter>().first;
}

Widget _host(Size size, int agents, {ValueChanged<String>? onTarget}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: size, disableAnimations: true),
        child: Scaffold(
          body: OfficeView(
            session: sessionOf(agents),
            sprites: loadSprites(),
            env: environmentAt(DateTime(2026, 10, 26, 12, 0)),
            serverNow: 1000000,
            onTarget: onTarget,
          ),
        ),
      ),
    );
