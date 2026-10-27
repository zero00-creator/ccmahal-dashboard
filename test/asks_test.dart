import 'dart:io';

import 'package:ccmahal_dashboard/asks.dart';
import 'package:ccmahal_dashboard/paths.dart';
import 'package:ccmahal_dashboard/sprites.dart';
import 'package:ccmahal_dashboard/theme/tokens.dart';
import 'package:ccmahal_dashboard/ui/alerts_tab.dart';
import 'package:ccmahal_dashboard/ui/ask_dialog.dart';
import 'package:ccmahal_dashboard/ui/settings_tab.dart';
import 'package:ccmahal_dashboard/ui/tab_bar.dart';
import 'package:ccmahal_dashboard/auth/auth_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> raw({
  String status = 'pending',
  int at = 1000,
  String? why = 'deletes files',
  String? by,
}) => {
  'v': 1,
  'tool': 'Bash',
  'detail': 'rm -rf build',
  'why': ?why,
  'session': 'my project',
  'createdAt': at,
  'status': status,
  'answeredBy': ?by,
};

AskInfo ask(
  String id, {
  String status = 'pending',
  int at = 1000,
  String? why = 'deletes files',
  String? by,
}) => parseAsks({
  's1': {id: raw(status: status, at: at, why: why, by: by)},
}).single;

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

  test(
    'asksPath and prefsPath build the per-person paths and refuse a bad uid',
    () {
      expect(asksPath('u1'), 'users/u1/asks');
      expect(appAskPath('u1'), 'users/u1/prefs/appAsk');
      expect(() => asksPath('a/b'), throwsArgumentError);
      expect(() => appAskPath(''), throwsArgumentError);
    },
  );

  test(
    'parseAsks reads the nested map, newest first, and skips what is malformed',
    () {
      final list = parseAsks({
        's1': {
          'old': raw(at: 1000, status: 'allowed', by: 'app'),
          'new': raw(at: 3000),
        },
        's2': {
          'mid': raw(at: 2000),
          'junk': 'nope',
          'nodetail': {'v': 1, 'status': 'pending'},
        },
        'bad': 5,
      });
      expect(list.map((a) => a.id), ['new', 'mid', 'old']);
      expect(list.first.sessionKey, 's1');
      expect(list.first.isPending, isTrue);
      expect(list.last.isPending, isFalse);
      expect(list.last.answeredBy, 'app');
      expect(list.first.tool, 'Bash');
      expect(list.first.detail, 'rm -rf build');
      expect(list.first.why, 'deletes files');
      expect(parseAsks(null), isEmpty);
      expect(parseAsks('x'), isEmpty);
    },
  );

  test('answerPath points at the one field the app may write', () {
    expect(ask('k1').answerPath('u1'), 'users/u1/asks/s1/k1/answer');
  });

  testWidgets(
    'the ask dialog shows who asks, the command and the danger, and answers',
    (tester) async {
      final answers = <bool>[];
      await tester.pumpWidget(
        host(
          AskDialogBody(
            ask: ask('k1'),
            style: style,
            waited: const Duration(minutes: 2, seconds: 5),
            onAnswer: answers.add,
          ),
        ),
      );
      expect(find.text('my project'), findsOneWidget);
      expect(find.textContaining('rm -rf build'), findsOneWidget);
      expect(find.textContaining('Dangerous: deletes files'), findsOneWidget);
      expect(find.textContaining('2 min'), findsOneWidget);
      for (final k in ['ask-deny', 'ask-accept']) {
        expect(
          tester.getSize(find.byKey(ValueKey(k))).height,
          greaterThanOrEqualTo(minTap),
          reason: k,
        );
      }
      await tester.tap(find.byKey(const ValueKey('ask-deny')));
      await tester.tap(find.byKey(const ValueKey('ask-accept')));
      expect(answers, [false, true]);
    },
  );

  testWidgets('an ask without a danger reason shows no danger tag', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AskDialogBody(
          ask: ask('k1', why: null),
          style: style,
          waited: Duration.zero,
          onAnswer: (_) {},
        ),
      ),
    );
    expect(find.textContaining('Dangerous'), findsNothing);
  });

  testWidgets(
    'the Alerts tab lists open questions first with buttons, then recent ones with who answered',
    (tester) async {
      final answers = <String>[];
      await tester.pumpWidget(
        host(
          AlertsTab(
            asks: [
              ask('a', at: 3000),
              ask('b', status: 'allowed', at: 2000, by: 'app'),
              ask('c', status: 'expired', at: 1000),
            ],
            style: style,
            waitedNow: 5000,
            onAnswer: (a, allow) => answers.add('${a.id}:$allow'),
          ),
        ),
      );
      expect(find.byKey(const ValueKey('alert-accept-a')), findsOneWidget);
      expect(find.byKey(const ValueKey('alert-accept-b')), findsNothing);
      expect(find.textContaining('Allowed in the app'), findsOneWidget);
      expect(find.textContaining('No answer in time'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('alert-deny-a')));
      expect(answers, ['a:false']);
    },
  );

  testWidgets('an empty Alerts tab says there is nothing to answer', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        AlertsTab(
          asks: const [],
          style: style,
          waitedNow: 0,
          onAnswer: (_, _) {},
        ),
      ),
    );
    expect(find.textContaining('Nothing waiting'), findsOneWidget);
  });

  testWidgets(
    'the tab bar has four tabs and a badge on Alerts when something waits',
    (tester) async {
      final taps = <int>[];
      await tester.pumpWidget(
        host(
          Align(
            alignment: Alignment.bottomCenter,
            child: GlassTabBar(
              index: 0,
              onChanged: taps.add,
              style: style,
              alertCount: 2,
            ),
          ),
        ),
      );
      for (final t in ['Office', 'Agents', 'Alerts', 'Settings']) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      expect(find.byKey(const ValueKey('alert-badge')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('alert-badge')),
          matching: find.text('2'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Alerts'));
      await tester.tap(find.text('Settings'));
      expect(taps, [2, 3]);
    },
  );

  testWidgets('no badge when nothing waits', (tester) async {
    await tester.pumpWidget(
      host(
        Align(
          alignment: Alignment.bottomCenter,
          child: GlassTabBar(index: 0, onChanged: (_) {}, style: style),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('alert-badge')), findsNothing);
  });

  testWidgets('the Settings switch Ask me here reports the new value', (
    tester,
  ) async {
    final seen = <bool>[];
    await tester.pumpWidget(
      host(
        SettingsTab(
          user: const AuthUser('u', 'a@b.c'),
          style: style,
          onSignOut: () {},
          onSetPluginPassword: (_) async {},
          appAsk: false,
          onAppAskChanged: seen.add,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('app-ask')));
    await tester.pump();
    expect(seen, [true]);
  });

  test('sprites asset loads (sanity for the other tests)', () {
    expect(
      SpriteSet.fromJson(File('assets/sprites.json').readAsStringSync()),
      isNotNull,
    );
  });
}
