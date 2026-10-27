import 'dart:async';
import 'dart:io';

import 'package:ccmahal_dashboard/auth/auth_service.dart';
import 'package:ccmahal_dashboard/models.dart';
import 'package:ccmahal_dashboard/sprites.dart';
import 'package:ccmahal_dashboard/theme/tokens.dart';
import 'package:ccmahal_dashboard/ui/live_view.dart';
import 'package:ccmahal_dashboard/ui/settings_tab.dart';
import 'package:ccmahal_dashboard/update/update_controller.dart';
import 'package:ccmahal_dashboard/update/update_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_update.dart';

final style = glassFor(1);

Widget settings(UpdateController? c) => MaterialApp(
  home: Scaffold(
    body: SettingsTab(
      user: const AuthUser('u', 'me@example.com'),
      style: style,
      onSignOut: () {},
      onSetPluginPassword: (_) async {},
      updates: c,
    ),
  ),
);

Widget live(UpdateController? c) {
  final sprites = SpriteSet.fromJson(
    File('assets/sprites.json').readAsStringSync(),
  );
  return MaterialApp(
    home: LiveView(
      sessions: [
        SessionInfo.fromMap('a', {
          'project': 'alpha',
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
        }),
      ],
      serverNow: 1000000,
      sprites: sprites,
      now: DateTime(2026, 10, 26, 12, 0),
      user: const AuthUser('u', 'me@example.com'),
      onSetPluginPassword: (_) async {},
      updates: c,
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

const _key = ValueKey('update-banner');

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  late FakeUpdateService svc;
  late UpdateController c;
  setUp(() {
    svc = FakeUpdateService();
    c = UpdateController(service: svc);
  });

  group('Settings section', () {
    testWidgets('idle: version and the check button, no update lines', (
      tester,
    ) async {
      surface(tester, 400, 1400);
      await tester.pumpWidget(settings(c));
      expect(find.text('App updates'), findsOneWidget);
      expect(find.byKey(const ValueKey('update-check')), findsOneWidget);
      expect(find.byKey(const ValueKey('update-start')), findsNothing);
      expect(
        tester.getSize(find.byKey(const ValueKey('update-check'))).height,
        greaterThanOrEqualTo(minTap),
      );
    });

    testWidgets('checking, up to date', (tester) async {
      surface(tester, 400, 1400);
      svc.latest = null;
      await tester.pumpWidget(settings(c));
      await tester.tap(find.byKey(const ValueKey('update-check')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Current version 1.0.0'), findsOneWidget);
      expect(find.byKey(const ValueKey('update-uptodate')), findsOneWidget);
    });

    testWidgets('available: version, notes, Update, the install-allow line', (
      tester,
    ) async {
      surface(tester, 400, 1400);
      await tester.pumpWidget(settings(c));
      await tester.tap(find.byKey(const ValueKey('update-check')));
      await tester.pump();
      await tester.pump();
      expect(find.text('New version 1.0.1'), findsOneWidget);
      expect(find.text('Fixes things'), findsOneWidget);
      expect(find.textContaining('asks once'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('update-start'))).height,
        greaterThanOrEqualTo(minTap),
      );
    });

    testWidgets('downloading shows progress, then Install opens it', (
      tester,
    ) async {
      surface(tester, 400, 1400);
      await c.checkManual();
      await tester.pumpWidget(settings(c));
      await tester.tap(find.byKey(const ValueKey('update-start')));
      await tester.pump();
      await tester.pump();
      expect(find.byKey(const ValueKey('update-install')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('update-install')));
      await tester.pump();
      expect(svc.installs, 1);
    });

    testWidgets('progress bar while downloading', (tester) async {
      surface(tester, 400, 1400);
      await c.checkManual();
      svc.gate = Completer<void>();
      await tester.pumpWidget(settings(c));
      await tester.tap(find.byKey(const ValueKey('update-start')));
      await tester.pump();
      final bar = tester.widget<LinearProgressIndicator>(
        find.byKey(const ValueKey('update-progress')),
      );
      expect(bar.value, 0.4);
      expect(find.text('Downloading 40%'), findsOneWidget);
      svc.gate!.complete();
      await tester.pump();
    });

    testWidgets('a failed manual check shows the message', (tester) async {
      surface(tester, 400, 1400);
      svc.checkError = Exception('x');
      await tester.pumpWidget(settings(c));
      await tester.tap(find.byKey(const ValueKey('update-check')));
      await tester.pump();
      await tester.pump();
      expect(find.text('Could not check for updates'), findsOneWidget);
    });

    testWidgets('hidden when unsupported (web) or no controller', (
      tester,
    ) async {
      surface(tester, 400, 1400);
      await tester.pumpWidget(
        settings(UpdateController(service: svc, supported: false)),
      );
      expect(find.text('App updates'), findsNothing);
      await tester.pumpWidget(settings(null));
      expect(find.text('App updates'), findsNothing);
    });

    test('updates exist only on Android, not on other platforms', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(updatesSupported, isTrue);
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(updatesSupported, isFalse);
      debugDefaultTargetPlatformOverride = null;
    });
  });

  group('banner', () {
    testWidgets('phone: shows when an update is known, taps open Settings', (
      tester,
    ) async {
      surface(tester, 400, 800);
      await tester.pumpWidget(live(c));
      await settle(tester);
      expect(find.byKey(_key), findsNothing);
      await c.checkManual();
      await settle(tester);
      expect(find.text('Update available - v1.0.1'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('update-banner-open'))).height,
        greaterThanOrEqualTo(minTap),
      );
      await tester.tap(find.byKey(const ValueKey('update-banner-open')));
      await settle(tester);
      expect(find.text('App updates'), findsOneWidget);
    });

    testWidgets('phone: dismiss hides it', (tester) async {
      surface(tester, 400, 800);
      await c.checkManual();
      await tester.pumpWidget(live(c));
      await settle(tester);
      expect(find.byKey(_key), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('update-banner-dismiss')));
      await settle(tester);
      expect(find.byKey(_key), findsNothing);
    });

    testWidgets('wide: banner in the centre column opens the Settings panel', (
      tester,
    ) async {
      surface(tester, 1920, 1080);
      await c.checkManual();
      await tester.pumpWidget(live(c));
      await settle(tester);
      expect(find.byKey(_key), findsOneWidget);
      expect(find.text('App updates'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('update-banner-open')));
      await settle(tester);
      expect(find.text('App updates'), findsOneWidget);
    });

    testWidgets('hidden when unsupported, and when up to date', (tester) async {
      surface(tester, 400, 800);
      final off = UpdateController(service: svc, supported: false);
      await tester.pumpWidget(live(off));
      await settle(tester);
      expect(find.byKey(_key), findsNothing);
      svc.latest = null;
      await c.checkManual();
      await tester.pumpWidget(live(c));
      await settle(tester);
      expect(find.byKey(_key), findsNothing);
    });
  });
}
