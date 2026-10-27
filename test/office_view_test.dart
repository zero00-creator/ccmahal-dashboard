import 'dart:io';

import 'package:ccmahal_dashboard/environment.dart';
import 'package:ccmahal_dashboard/models.dart';
import 'package:ccmahal_dashboard/office/office_view.dart';
import 'package:ccmahal_dashboard/sprites.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host({
  required bool reduced,
  required void Function() onPaint,
  ValueChanged<String>? onTarget,
}) {
  final sprites = SpriteSet.fromJson(
    File('assets/sprites.json').readAsStringSync(),
  );
  final session = SessionInfo.fromMap('k', {
    'project': 'p',
    'status': 'running',
    'seenAt': 1000000,
    'agents': [
      {
        'id': 'a1',
        'type': 'coder-low',
        'task': 't',
        'status': 'running',
        'startedAt': 1,
      },
    ],
  });
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: const Size(400, 800),
        disableAnimations: reduced,
      ),
      child: Scaffold(
        body: OfficeView(
          session: session,
          sprites: sprites,
          env: environmentAt(DateTime(2026, 10, 26, 12, 0)),
          serverNow: 1000000,
          debugOnPaint: onPaint,
          onTarget: onTarget,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'the office repaints about 12 times a second, not at the screen rate',
    (tester) async {
      var paints = 0;
      await tester.pumpWidget(host(reduced: false, onPaint: () => paints++));
      paints = 0;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(paints, inInclusiveRange(8, 16));
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'with animations off the office paints once and then stays still',
    (tester) async {
      var paints = 0;
      await tester.pumpWidget(host(reduced: true, onPaint: () => paints++));
      final first = paints;
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(paints, first);
      expect(first, greaterThanOrEqualTo(1));
    },
  );

  testWidgets('disposing the office leaves no timer running', (tester) async {
    await tester.pumpWidget(host(reduced: false, onPaint: () {}));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tapping a crab shows its name and status, tapping empty floor shows nothing, and the chip goes after 4 seconds',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(host(reduced: true, onPaint: () {}));
      final box = tester.getRect(find.byType(OfficeView));
      final s = box.width / 260; // the scene is 260 cells wide
      // the first agent's desk is (1.0, 0.9): its feet are at iso(1.2, 1.55)
      Offset feet(double gx, double gy) =>
          box.topLeft +
          Offset((130 + (gx - gy) * 14) * s, (150 + (gx + gy) * 7) * s);
      await tester.tapAt(feet(1.2, 1.55) - Offset(0, 14 * s));
      await tester.pump();
      expect(find.byKey(const ValueKey('crab-chip')), findsOneWidget);
      expect(find.textContaining('coder-low'), findsWidgets);
      await tester.pump(const Duration(seconds: 5));
      expect(find.byKey(const ValueKey('crab-chip')), findsNothing);
      await tester.tapAt(box.topLeft + const Offset(5, 5));
      await tester.pump();
      expect(find.byKey(const ValueKey('crab-chip')), findsNothing);
    },
  );

  testWidgets(
    'with onTarget set, tapping a crab reports its type instead of showing the chip',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final got = <String>[];
      await tester.pumpWidget(
        host(reduced: true, onPaint: () {}, onTarget: got.add),
      );
      final box = tester.getRect(find.byType(OfficeView));
      final s = box.width / 260;
      Offset feet(double gx, double gy) =>
          box.topLeft +
          Offset((130 + (gx - gy) * 14) * s, (150 + (gx + gy) * 7) * s);
      await tester.tapAt(feet(1.2, 1.55) - Offset(0, 14 * s));
      await tester.pump();
      expect(got, ['coder-low']);
      expect(find.byKey(const ValueKey('crab-chip')), findsNothing);
    },
  );
}
