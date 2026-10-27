import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:ccmahal_dashboard/environment.dart';
import 'package:ccmahal_dashboard/models.dart';
import 'package:ccmahal_dashboard/office/iso_painter.dart';
import 'package:ccmahal_dashboard/sprites.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const size = Size(780, 1350);

SpriteSet loadSprites() =>
    SpriteSet.fromJson(File('assets/sprites.json').readAsStringSync());

AgentInfo agent(
  int i, {
  String status = 'running',
  String type = 'coder-low',
}) => AgentInfo(
  id: 'a$i',
  type: type,
  task: 'task $i',
  model: 'm',
  status: status,
  startedAt: i,
  costUsd: 0,
  stepNote: 'note',
);

SessionInfo session({
  int agents = 3,
  String project = 'my-mod',
  int pending = 0,
  String status = 'running',
  String title = '',
}) {
  return SessionInfo(
    key: 'k',
    project: project,
    title: title,
    status: status,
    model: 'opus',
    mode: 'auto',
    limits: const {},
    agents: [
      for (var i = 0; i < agents; i++)
        agent(i, status: i % 3 == 2 ? 'done' : 'running'),
    ],
    flowTitle: '',
    allowed: 1,
    you: 0,
    pending: pending,
    denied: 0,
    seenAt: 1000000,
  );
}

IsoOfficePainter painterFor(
  SessionInfo s,
  Environment env, {
  double clock = 1.37,
}) => IsoOfficePainter(
  session: s,
  sprites: loadSprites(),
  env: env,
  clock: () => clock,
  serverNow: 1000000,
);

Future<ByteData> render(IsoOfficePainter p) async {
  final rec = ui.PictureRecorder();
  p.paint(Canvas(rec), size);
  final img = await rec.endRecording().toImage(
    size.width.toInt(),
    size.height.toInt(),
  );
  return (await img.toByteData(format: ui.ImageByteFormat.rawRgba))!;
}

double lum(ByteData d, Offset o) {
  final i = ((o.dy.round() * size.width.toInt()) + o.dx.round()) * 4;
  return 0.2126 * d.getUint8(i) +
      0.7152 * d.getUint8(i + 1) +
      0.0722 * d.getUint8(i + 2);
}

Environment at(int h, int m) => environmentAt(DateTime(2026, 10, 26, h, m));

void main() {
  testWidgets('renders every stage with 0, 1, 8 and 12 agents without error', (
    tester,
  ) async {
    await tester.runAsync(() async {
      for (final env in [at(7, 0), at(12, 0), at(18, 30), at(21, 41)]) {
        for (final n in [0, 1, 8, 12]) {
          final bytes = await render(painterFor(session(agents: n), env));
          expect(
            bytes.lengthInBytes,
            size.width.toInt() * size.height.toInt() * 4,
          );
        }
      }
    });
  });

  testWidgets('the window is brighter at noon than at 21:41', (tester) async {
    await tester.runAsync(() async {
      final noonP = painterFor(session(), at(12, 0));
      final nightP = painterFor(session(), at(21, 41));
      final w = noonP.geometry(size).windowCenter;
      final noon = lum(await render(noonP), w);
      final night = lum(await render(nightP), w);
      expect(noon - night, greaterThan(60));
    });
  });

  testWidgets('lamps glow at night and not at noon', (tester) async {
    await tester.runAsync(() async {
      final nightP = painterFor(session(), at(21, 41));
      final noonP = painterFor(session(), at(12, 0));
      final lamp = nightP.geometry(size).lamps.first;
      final away = lamp + Offset(0, size.width * 0.15);
      final night = await render(nightP);
      final noon = await render(noonP);
      expect(lum(night, lamp) - lum(night, away), greaterThan(15));
      expect((lum(noon, lamp) - lum(noon, away)).abs(), lessThan(40));
    });
  });

  testWidgets(
    'with a frozen clock two paints are identical, and moving the clock changes working crabs',
    (tester) async {
      await tester.runAsync(() async {
        final a = await render(painterFor(session(), at(12, 0), clock: 2.0));
        final b = await render(painterFor(session(), at(12, 0), clock: 2.0));
        final c = await render(painterFor(session(), at(12, 0), clock: 2.4));
        expect(Uint8List.sublistView(a), equals(Uint8List.sublistView(b)));
        expect(
          Uint8List.sublistView(a),
          isNot(equals(Uint8List.sublistView(c))),
        );
      });
    },
  );

  testWidgets('the session name is drawn on the board', (tester) async {
    await tester.runAsync(() async {
      final a = await render(painterFor(session(project: 'alpha'), at(12, 0)));
      final b = await render(
        painterFor(session(project: 'bravo-long'), at(12, 0)),
      );
      expect(Uint8List.sublistView(a), isNot(equals(Uint8List.sublistView(b))));
    });
  });

  testWidgets('a 200-character project name does not throw', (tester) async {
    await tester.runAsync(() async {
      await render(painterFor(session(project: 'x' * 200), at(12, 0)));
    });
  });

  testWidgets('a waiting main shows a different picture from a working one', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final a = await render(
        painterFor(session(pending: 0), at(12, 0), clock: 0),
      );
      final b = await render(
        painterFor(session(pending: 1), at(12, 0), clock: 0),
      );
      expect(Uint8List.sublistView(a), isNot(equals(Uint8List.sublistView(b))));
    });
  });

  testWidgets('seatAt returns the seat under a crab and null on empty floor', (
    tester,
  ) async {
    final p = painterFor(session(agents: 3), at(12, 0));
    final g = p.geometry(size);
    // A crab is 28 cells tall and stands on its seat point: its middle is half that above.
    final middle = g.seatPoints.first - Offset(0, 14 * g.scale);
    expect(
      p.seatAt(middle, size)?.agent,
      isNull,
    ); // the first seat is the main desk
    expect(p.seatAt(const Offset(4, 4), size), isNull);
    expect(p.seatAt(Offset(size.width - 4, size.height - 4), size), isNull);
  });

  testWidgets('with 8 agents every seat can be hit', (tester) async {
    final p = painterFor(session(agents: 12), at(12, 0));
    final g = p.geometry(size);
    expect(g.seatPoints, hasLength(8));
    for (var i = 0; i < g.seatPoints.length; i++) {
      final hit = p.seatAt(g.seatPoints[i] - Offset(0, 14 * g.scale), size);
      expect(hit, isNotNull, reason: 'seat $i');
    }
  });

  testWidgets(
    'the board shows the session title when there is one, else the project',
    (tester) async {
      await tester.runAsync(() async {
        final named = await render(
          painterFor(session(project: 'p1', title: 'Named'), at(12, 0)),
        );
        final projectOnly = await render(
          painterFor(session(project: 'Named'), at(12, 0)),
        );
        final differentProject = await render(
          painterFor(session(project: 'p1'), at(12, 0)),
        );
        expect(
          Uint8List.sublistView(named),
          equals(Uint8List.sublistView(projectOnly)),
        );
        expect(
          Uint8List.sublistView(named),
          isNot(equals(Uint8List.sublistView(differentProject))),
        );
      });
    },
  );
}
