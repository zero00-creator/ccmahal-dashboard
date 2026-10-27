import 'dart:io';

import 'package:ccmahal_dashboard/asks.dart';
import 'package:ccmahal_dashboard/auth/auth_service.dart';
import 'package:ccmahal_dashboard/models.dart';
import 'package:ccmahal_dashboard/office/office_view.dart';
import 'package:ccmahal_dashboard/sprites.dart';
import 'package:ccmahal_dashboard/ui/live_view.dart';
import 'package:ccmahal_dashboard/office/iso_painter.dart';
import 'package:ccmahal_dashboard/office/layout.dart';
import 'package:ccmahal_dashboard/ui/stats_strip.dart';
import 'package:ccmahal_dashboard/ui/tab_bar.dart';
import 'package:ccmahal_dashboard/ui/top_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const serverNow = 1000000;

SessionInfo session(String key, String project) => SessionInfo.fromMap(key, {
  'project': project,
  'status': 'running',
  'seenAt': 990000,
  'firstSeen': 1,
  'gate': {'pending': 0},
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

AskInfo pendingAsk(String id) => parseAsks({
  's1': {
    id: {
      'v': 1,
      'tool': 'Bash',
      'detail': 'rm -rf build',
      'why': 'deletes files',
      'session': 'alpha',
      'createdAt': serverNow,
      'status': 'pending',
    },
  },
}).single;

Widget app({
  List<SessionInfo>? sessions,
  List<AskInfo> asks = const [],
  VoidCallback? onSignOut,
  Future<void> Function(AskInfo, bool)? onAnswer,
}) {
  final sprites = SpriteSet.fromJson(
    File('assets/sprites.json').readAsStringSync(),
  );
  return MaterialApp(
    home: LiveView(
      sessions: sessions ?? [session('a', 'alpha'), session('b', 'beta')],
      serverNow: serverNow,
      sprites: sprites,
      now: DateTime(2026, 10, 26, 12, 0),
      user: const AuthUser('u', 'me@example.com'),
      onSetPluginPassword: (_) async {},
      onSignOut: onSignOut,
      asks: asks,
      onAnswer: onAnswer,
      appCmd: true,
    ),
  );
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump(const Duration(milliseconds: 400));
}

void surface(WidgetTester tester, double w, double h) {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('wide: sessions panel is always open, no drawer or tab bar', (
    tester,
  ) async {
    surface(tester, 1920, 1080);
    var out = 0;
    await tester.pumpWidget(app(onSignOut: () => out++));
    await settle(tester);
    expect(find.byKey(const ValueKey('row-a')), findsOneWidget);
    expect(find.byKey(const ValueKey('row-b')), findsOneWidget);
    expect(find.byType(Drawer), findsNothing);
    expect(find.byType(GlassTabBar), findsNothing);
    expect(find.byTooltip('Sessions'), findsNothing);
    expect(
      tester.getSize(find.byKey(const ValueKey('sessions-panel'))).width,
      closeTo(280, 1),
    );
    await tester.tap(find.byKey(const ValueKey('sign-out')));
    expect(out, 1);
    expect(find.byType(TopCard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide: selecting a session in the panel switches it', (
    tester,
  ) async {
    surface(tester, 1920, 1080);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(
      find.descendant(of: find.byType(TopCard), matching: find.text('alpha')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('row-b')));
    await settle(tester);
    expect(
      find.descendant(of: find.byType(TopCard), matching: find.text('beta')),
      findsOneWidget,
    );
  });

  testWidgets('wide: right column holds coworkers, prompt, Alerts, Settings', (
    tester,
  ) async {
    surface(tester, 1920, 1080);
    await tester.pumpWidget(app());
    await settle(tester);
    final right = find.byKey(const ValueKey('right-column'));
    expect(right, findsOneWidget);
    expect(
      tester.getSize(right).width,
      closeTo(440, 1),
    ); // 1920 px is above 1600
    Finder inRight(Finder f) => find.descendant(of: right, matching: f);
    expect(inRight(find.text('Coworkers')), findsOneWidget);
    expect(inRight(find.byKey(const ValueKey('coworker-a1'))), findsOneWidget);
    expect(inRight(find.byKey(const ValueKey('cmd-chip-all'))), findsOneWidget);
    expect(inRight(find.byKey(const ValueKey('panel-alerts'))), findsOneWidget);
    expect(
      inRight(find.byKey(const ValueKey('panel-settings'))),
      findsOneWidget,
    );
    // Collapsed at first; opening shows the existing tab content.
    expect(find.byKey(const ValueKey('app-ask')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('panel-settings')));
    await settle(tester);
    expect(inRight(find.byKey(const ValueKey('app-ask'))), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('panel-settings')));
    await settle(tester);
    expect(find.byKey(const ValueKey('app-ask')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('panel-alerts')));
    await settle(tester);
    expect(find.text('Nothing waiting for you.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'wide: tapping a chip opens the agent sheet in the right column',
    (tester) async {
      surface(tester, 1920, 1080);
      await tester.pumpWidget(app());
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('cmd-chip-main')));
      await settle(tester);
      final sheet = find.byKey(const ValueKey('sheet-close'));
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('right-column')),
          matching: sheet,
        ),
        findsOneWidget,
      );
      await tester.tap(sheet);
      await settle(tester);
      expect(find.byKey(const ValueKey('sheet-close')), findsNothing);
    },
  );

  testWidgets('wide: pending ask shows a badge on Alerts and a capped dialog', (
    tester,
  ) async {
    surface(tester, 1920, 1080);
    final answered = <String>[];
    await tester.pumpWidget(
      app(
        asks: [pendingAsk('k1')],
        onAnswer: (a, allow) async => answered.add('${a.id}:$allow'),
      ),
    );
    await settle(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('panel-alerts')),
        matching: find.byKey(const ValueKey('alert-badge')),
      ),
      findsOneWidget,
    );
    final body = find.byKey(const ValueKey('ask-detail'));
    expect(body, findsOneWidget);
    final dialog = find.byKey(const ValueKey('ask-card'));
    final size = tester.getSize(dialog);
    expect(size.width, lessThanOrEqualTo(480));
    expect(size.width, greaterThan(300));
    expect(tester.getCenter(dialog).dx, closeTo(960, 1));
    await tester.tap(find.byKey(const ValueKey('ask-accept')));
    await settle(tester);
    expect(answered, ['k1:true']);
  });

  testWidgets('phone: still has the tab bar and the drawer', (tester) async {
    surface(tester, 390, 844);
    await tester.pumpWidget(app(onSignOut: () {}));
    await settle(tester);
    expect(find.byType(GlassTabBar), findsOneWidget);
    expect(find.byKey(const ValueKey('right-column')), findsNothing);
    expect(find.byKey(const ValueKey('row-a')), findsNothing);
    await tester.tap(find.byTooltip('Sessions').first);
    await settle(tester);
    expect(find.byType(Drawer), findsOneWidget);
    expect(find.byKey(const ValueKey('row-a')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone: the ask dialog is not capped differently', (
    tester,
  ) async {
    surface(tester, 390, 844);
    await tester.pumpWidget(app(asks: [pendingAsk('k1')]));
    await settle(tester);
    final w = tester.getSize(find.byKey(const ValueKey('ask-card'))).width;
    expect(w, closeTo(390 - 32, 1));
  });

  testWidgets('899 px is phone, 900 px is wide', (tester) async {
    surface(tester, 899, 900);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.byType(GlassTabBar), findsOneWidget);
    surface(tester, 900, 900);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(find.byType(GlassTabBar), findsNothing);
    expect(find.byKey(const ValueKey('right-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('right column is 380 below 1600 px and 440 from 1600 px', (
    tester,
  ) async {
    surface(tester, 1599, 900);
    await tester.pumpWidget(app());
    await settle(tester);
    final right = find.byKey(const ValueKey('right-column'));
    expect(tester.getSize(right).width, closeTo(380, 1));
    surface(tester, 1600, 900);
    await tester.pumpWidget(app());
    await settle(tester);
    expect(tester.getSize(right).width, closeTo(440, 1));
  });

  testWidgets(
    'wide 1920x1080: the office fills the centre column, wide scene, stats strip above',
    (tester) async {
      surface(tester, 1920, 1080);
      await tester.pumpWidget(app());
      await settle(tester);
      expect(find.byType(StatsStrip), findsOneWidget);
      final office = tester.getRect(find.byType(OfficeView));
      final topCard = tester.getRect(find.byType(TopCard));
      final strip = tester.getRect(find.byType(StatsStrip));
      // centre column: 1920 - 16 pad - 280 - 8 - 8 - 440 = 1168 px wide
      expect(office.width, closeTo(1168, 2));
      expect(topCard.width, closeTo(office.width, 2)); // no 720 cap
      expect(strip.top, lessThan(topCard.top + 1));
      expect(office.top, greaterThanOrEqualTo(topCard.bottom));
      expect(office.bottom, closeTo(1080 - 8, 2));
      final painter = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(OfficeView),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((c) => c.painter)
          .whereType<IsoOfficePainter>()
          .first;
      expect(painter.scene, SceneKind.wide);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'phone 390x844: compact scene, no stats strip, card capped as before',
    (tester) async {
      surface(tester, 390, 844);
      await tester.pumpWidget(app());
      await settle(tester);
      expect(find.byType(StatsStrip), findsNothing);
      final painter = tester
          .widgetList<CustomPaint>(
            find.descendant(
              of: find.byType(OfficeView),
              matching: find.byType(CustomPaint),
            ),
          )
          .map((c) => c.painter)
          .whereType<IsoOfficePainter>()
          .first;
      expect(painter.scene, SceneKind.compact);
      final box = tester.getSize(find.byType(OfficeView));
      expect(box.width / box.height, closeTo(sceneW / sceneH, 0.01));
    },
  );
}
