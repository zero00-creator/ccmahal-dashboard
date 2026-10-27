import 'dart:io';

import 'package:ccmahal_dashboard/auth/auth_service.dart';
import 'package:ccmahal_dashboard/models.dart';
import 'package:ccmahal_dashboard/sprites.dart';
import 'package:ccmahal_dashboard/theme/tokens.dart';
import 'package:ccmahal_dashboard/ui/coworkers.dart';
import 'package:ccmahal_dashboard/ui/settings_tab.dart';
import 'package:ccmahal_dashboard/ui/tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SpriteSet sprites() =>
    SpriteSet.fromJson(File('assets/sprites.json').readAsStringSync());

AgentInfo agent(
  int i, {
  String status = 'running',
  String task = 'task',
  int? stepTotal,
  int? stepDone,
  String note = '',
  String type = 'coder-low',
}) => AgentInfo(
  id: 'a$i',
  type: type,
  task: task,
  model: 'm',
  status: status,
  startedAt: i,
  costUsd: 0.5,
  ctxPct: 30,
  stepDone: stepDone,
  stepTotal: stepTotal,
  stepNote: note,
);

Widget host(Widget child, {double width = 400, double height = 800}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, height)),
        child: Scaffold(
          body: SizedBox(width: width, height: height, child: child),
        ),
      ),
    );

void main() {
  final style = glassFor(1);

  testWidgets('the tab bar shows four tabs and reports the tapped index', (
    tester,
  ) async {
    final taps = <int>[];
    await tester.pumpWidget(
      host(
        Align(
          alignment: Alignment.bottomCenter,
          child: GlassTabBar(index: 0, onChanged: taps.add, style: style),
        ),
      ),
    );
    expect(find.text('Office'), findsOneWidget);
    expect(find.text('Agents'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.text('Settings'));
    await tester.tap(find.text('Agents'));
    expect(taps, [3, 1]);
  });

  testWidgets('tabs are at least 44 px', (tester) async {
    await tester.pumpWidget(
      host(
        Align(
          alignment: Alignment.bottomCenter,
          child: GlassTabBar(index: 1, onChanged: (_) {}, style: style),
        ),
      ),
    );
    for (final k in ['tab-0', 'tab-1', 'tab-2', 'tab-3']) {
      final s = tester.getSize(find.byKey(ValueKey(k)));
      expect(s.height, greaterThanOrEqualTo(minTap), reason: k);
      expect(s.width, greaterThanOrEqualTo(minTap), reason: k);
    }
  });

  testWidgets(
    'the sheet shows two rows collapsed and every row after a drag up',
    (tester) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final agents = [for (var i = 0; i < 6; i++) agent(i)];
      await tester.pumpWidget(
        host(
          Stack(
            children: [
              CoworkersSheet(agents: agents, sprites: sprites(), style: style),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('coworker-a0')), findsOneWidget);
      expect(find.byKey(const ValueKey('coworker-a1')), findsOneWidget);
      expect(find.byKey(const ValueKey('coworker-a5')), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('sheet-handle')),
        const Offset(0, -500),
      );
      await tester.pump(const Duration(milliseconds: 400));
      for (var i = 0; i < 6; i++) {
        expect(
          find.byKey(ValueKey('coworker-a$i')),
          findsOneWidget,
          reason: 'a$i',
        );
      }
    },
  );

  testWidgets(
    'a row with no steps has no progress bar; a row with steps has one',
    (tester) async {
      await tester.pumpWidget(
        host(
          AgentsList(
            agents: [
              agent(1),
              agent(2, stepTotal: 4, stepDone: 1, note: 'writing tests'),
            ],
            sprites: sprites(),
            style: style,
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('coworker-a1')),
          matching: find.byType(LinearProgressIndicator),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('coworker-a2')),
          matching: find.byType(LinearProgressIndicator),
        ),
        findsOneWidget,
      );
      expect(find.text('writing tests'), findsOneWidget);
    },
  );

  testWidgets('a 200-character task is ellipsized and does not overflow', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AgentsList(
          agents: [agent(1, task: 'x' * 200)],
          sprites: sprites(),
          style: style,
        ),
        width: 320,
      ),
    );
    expect(tester.takeException(), isNull);
    final t = tester.widget<Text>(find.textContaining('xxxxxxxx'));
    expect(t.overflow, TextOverflow.ellipsis);
  });

  testWidgets('every skin draws as a crab icon without error', (tester) async {
    final all = [
      'head',
      'planning',
      'manager',
      'coder-high',
      'coder-low',
      'debugger',
      'ask-anything',
      'design',
      'unknown-type',
    ];
    await tester.pumpWidget(
      host(
        AgentsList(
          agents: [for (var i = 0; i < all.length; i++) agent(i, type: all[i])],
          sprites: sprites(),
          style: style,
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('the Agents list shows every agent', (tester) async {
    await tester.pumpWidget(
      host(
        AgentsList(
          agents: [for (var i = 0; i < 4; i++) agent(i, task: 'job $i')],
          sprites: sprites(),
          style: style,
        ),
      ),
    );
    for (var i = 0; i < 4; i++) {
      expect(find.text('coder-low · job $i'), findsOneWidget);
    }
  });

  testWidgets('with no agents the Agents list says so', (tester) async {
    await tester.pumpWidget(
      host(AgentsList(agents: const [], sprites: sprites(), style: style)),
    );
    expect(find.textContaining('No agents'), findsOneWidget);
  });

  testWidgets('Settings shows the email and a working Sign out', (
    tester,
  ) async {
    var out = 0;
    await tester.pumpWidget(
      host(
        SettingsTab(
          user: const AuthUser('u', 'me@example.com'),
          style: style,
          onSignOut: () => out++,
          onSetPluginPassword: (_) async {},
        ),
      ),
    );
    expect(find.text('me@example.com'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('settings-sign-out')));
    expect(out, 1);
    expect(
      tester.getSize(find.byKey(const ValueKey('settings-sign-out'))).height,
      greaterThanOrEqualTo(minTap),
    );
  });

  testWidgets(
    'the plugin-password button appears only for an account without a password',
    (tester) async {
      await tester.pumpWidget(
        host(
          SettingsTab(
            user: const AuthUser('u', 'a@b.co'),
            style: style,
            onSignOut: () {},
            onSetPluginPassword: (_) async {},
          ),
        ),
      );
      expect(find.byKey(const ValueKey('set-plugin-password')), findsNothing);
      await tester.pumpWidget(
        host(
          SettingsTab(
            user: const AuthUser('u', 'a@b.co', hasPassword: false),
            style: style,
            onSignOut: () {},
            onSetPluginPassword: (_) async {},
          ),
        ),
      );
      expect(find.byKey(const ValueKey('set-plugin-password')), findsOneWidget);
    },
  );

  testWidgets(
    'a weak password is refused before any call, and a good one is sent',
    (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        host(
          SettingsTab(
            user: const AuthUser('u', 'a@b.co', hasPassword: false),
            style: style,
            onSignOut: () {},
            onSetPluginPassword: (p) async => calls.add(p),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('set-plugin-password')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('plugin-password')),
        '123',
      );
      await tester.tap(find.byKey(const ValueKey('plugin-password-save')));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);
      expect(find.textContaining('6 characters'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('plugin-password')),
        'secret1',
      );
      await tester.tap(find.byKey(const ValueKey('plugin-password-save')));
      await tester.pumpAndSettle();
      expect(calls, ['secret1']);
      expect(find.textContaining('Password set'), findsOneWidget);
    },
  );

  testWidgets(
    'a failing setPluginPassword shows its message and keeps the dialog open',
    (tester) async {
      await tester.pumpWidget(
        host(
          SettingsTab(
            user: const AuthUser('u', 'a@b.co', hasPassword: false),
            style: style,
            onSignOut: () {},
            onSetPluginPassword: (_) async =>
                throw AuthFailure(friendlyAuthError('requires-recent-login')),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('set-plugin-password')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('plugin-password')),
        'secret1',
      );
      await tester.tap(find.byKey(const ValueKey('plugin-password-save')));
      await tester.pumpAndSettle();
      expect(
        find.text(friendlyAuthError('requires-recent-login')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('plugin-password')), findsOneWidget);
    },
  );
}
