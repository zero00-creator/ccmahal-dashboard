import 'dart:io';

import 'package:ccmahal_dashboard/asks.dart';
import 'package:ccmahal_dashboard/auth/auth_service.dart';
import 'package:ccmahal_dashboard/cmds.dart';
import 'package:ccmahal_dashboard/models.dart';
import 'package:ccmahal_dashboard/ui/coworkers.dart';
import 'package:ccmahal_dashboard/sprites.dart';
import 'package:ccmahal_dashboard/ui/live_view.dart';
import 'package:ccmahal_dashboard/ui/top_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const serverNow = 1000000;

SessionInfo session(
  String key,
  String project, {
  String status = 'running',
  int seenAt = 990000,
  int firstSeen = 1,
  int pending = 0,
}) => SessionInfo.fromMap(key, {
  'project': project,
  'status': status,
  'seenAt': seenAt,
  'firstSeen': firstSeen,
  'gate': {'pending': pending},
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

Widget app(
  List<SessionInfo> sessions, {
  DateTime? now,
  bool reduced = false,
  double width = 400,
  double height = 800,
  VoidCallback? onSignOut,
  List<AskInfo> asks = const [],
  Future<void> Function(AskInfo, bool)? onAnswer,
  List<CmdInfo> cmds = const [],
  bool appCmd = true,
  Future<void> Function(String, String, String, {String? quick})? onSendCmd,
  ValueChanged<bool>? onAppCmdChanged,
}) {
  final sprites = SpriteSet.fromJson(
    File('assets/sprites.json').readAsStringSync(),
  );
  return MaterialApp(
    home: MediaQuery(
      data: MediaQueryData(
        size: Size(width, height),
        disableAnimations: reduced,
      ),
      child: LiveView(
        sessions: sessions,
        serverNow: serverNow,
        sprites: sprites,
        now: now ?? DateTime(2026, 10, 26, 12, 0),
        onSignOut: onSignOut,
        user: const AuthUser('u', 'me@example.com'),
        onSetPluginPassword: (_) async {},
        asks: asks,
        onAnswer: onAnswer,
        cmds: cmds,
        appCmd: appCmd,
        onSendCmd: onSendCmd,
        onAppCmdChanged: onAppCmdChanged,
      ),
    ),
  );
}

/// The office animates forever, so pumpAndSettle would never return: pump a fixed time.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> openDrawer(WidgetTester tester) async {
  await tester.dragFrom(const Offset(2, 400), const Offset(300, 0));
  await settle(tester);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('dragging from the left edge opens the sessions panel', (
    tester,
  ) async {
    await tester.pumpWidget(
      app([session('a', 'alpha'), session('b', 'bravo')]),
    );
    await settle(tester);
    expect(find.text('Sessions'), findsNothing);
    await openDrawer(tester);
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('bravo'), findsWidgets);
  });

  testWidgets(
    'rows show project and status, dimmed when offline, and ended sessions are not listed',
    (tester) async {
      await tester.pumpWidget(
        app([
          session('a', 'alpha'),
          session('b', 'bravo', status: 'ended', firstSeen: 2),
          session('c', 'charlie', seenAt: 900000, firstSeen: 3),
        ]),
      );
      await settle(tester);
      await openDrawer(tester);
      double opacityOf(String key) => tester
          .widget<Opacity>(find.byKey(ValueKey('row-opacity-$key')))
          .opacity;
      expect(opacityOf('a'), 1);
      expect(opacityOf('c'), lessThan(1));
      expect(find.byKey(const ValueKey('row-b')), findsNothing);
      expect(find.text('running'), findsWidgets);
      expect(find.text('offline'), findsWidgets);
    },
  );

  testWidgets('tapping a row selects it and closes the panel', (tester) async {
    await tester.pumpWidget(
      app([session('a', 'alpha'), session('b', 'bravo', firstSeen: 2)]),
    );
    await settle(tester);
    expect(
      find.descendant(of: find.byType(TopCard), matching: find.text('alpha')),
      findsOneWidget,
    );
    await openDrawer(tester);
    await tester.tap(find.byKey(const ValueKey('row-b')));
    await settle(tester);
    expect(find.text('Sessions'), findsNothing);
    expect(
      find.descendant(of: find.byType(TopCard), matching: find.text('bravo')),
      findsOneWidget,
    );
  });

  testWidgets(
    'with no sessions an empty message is shown instead of the room',
    (tester) async {
      await tester.pumpWidget(app(const []));
      await settle(tester);
      expect(find.textContaining('No session yet'), findsOneWidget);
    },
  );

  testWidgets('with reduced motion the environment is still applied', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        [session('a', 'alpha')],
        now: DateTime(2026, 10, 26, 21, 41),
        reduced: true,
      ),
    );
    await settle(tester);
    expect(find.textContaining('Night'), findsWidgets);
    expect(find.text('21:41'), findsWidgets);
  });

  testWidgets('a wide window shows the room without overflow', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      app([session('a', 'alpha')], width: 1280, height: 800),
    );
    await settle(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'the panel has a sign-out button that calls back and is at least 44 high',
    (tester) async {
      var out = 0;
      await tester.pumpWidget(
        app([session('a', 'alpha')], onSignOut: () => out++),
      );
      await settle(tester);
      await openDrawer(tester);
      expect(
        tester.getSize(find.byKey(const ValueKey('sign-out'))).height,
        greaterThanOrEqualTo(44),
      );
      await tester.tap(find.byKey(const ValueKey('sign-out')));
      expect(out, 1);
    },
  );

  testWidgets(
    'without a sign-out callback the panel shows no sign-out button',
    (tester) async {
      await tester.pumpWidget(app([session('a', 'alpha')]));
      await settle(tester);
      await openDrawer(tester);
      expect(find.byKey(const ValueKey('sign-out')), findsNothing);
    },
  );

  testWidgets(
    'the empty state with no sessions at all still has the menu and says no session yet',
    (tester) async {
      await tester.pumpWidget(app(const []));
      await settle(tester);
      expect(find.textContaining('No session yet'), findsOneWidget);
      expect(find.byTooltip('Sessions'), findsOneWidget);
    },
  );

  testWidgets('there is no list switch', (tester) async {
    await tester.pumpWidget(app([session('a', 'alpha')]));
    await settle(tester);
    expect(find.text('List'), findsNothing);
  });

  testWidgets('the panel rows have no swipe-to-hide', (tester) async {
    await tester.pumpWidget(app([session('a', 'alpha')]));
    await settle(tester);
    await openDrawer(tester);
    expect(find.byType(Dismissible), findsNothing);
  });

  testWidgets(
    'an ended session is not shown, and then the empty state keeps the menu and sign-out',
    (tester) async {
      var out = 0;
      await tester.pumpWidget(
        app([session('a', 'alpha', status: 'ended')], onSignOut: () => out++),
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('row-a')), findsNothing);
      expect(find.textContaining('No session yet'), findsOneWidget);
      await tester.tap(find.byTooltip('Sessions'));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('sign-out')));
      expect(out, 1);
    },
  );

  testWidgets('the Office tab has the Coworkers sheet', (tester) async {
    await tester.pumpWidget(app([session('a', 'alpha')]));
    await settle(tester);
    expect(find.text('Coworkers'), findsOneWidget);
    expect(find.text('Office'), findsOneWidget);
  });

  testWidgets('the tab bar switches between Office, Agents and Settings', (
    tester,
  ) async {
    await tester.pumpWidget(app([session('a', 'alpha')]));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('tab-1')));
    await settle(tester);
    expect(find.text('coder-low · t'), findsOneWidget);
    expect(find.text('Coworkers'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('tab-3')));
    await settle(tester);
    expect(find.text('me@example.com'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tab-0')));
    await settle(tester);
    expect(find.text('Coworkers'), findsOneWidget);
  });

  testWidgets(
    'the empty state still has the tab bar, so Settings is reachable',
    (tester) async {
      await tester.pumpWidget(app(const []));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('tab-3')));
      await settle(tester);
      expect(find.text('me@example.com'), findsOneWidget);
    },
  );

  testWidgets(
    'a panel row shows a crab icon, the project, the status and a summary with the cost',
    (tester) async {
      final s = SessionInfo.fromMap('a', {
        'project': 'alpha',
        'status': 'running',
        'seenAt': 990000,
        'firstSeen': 1,
        'meter': {'costUsd': 1.2},
        'agents': [
          {
            'id': 'a1',
            'type': 'coder-low',
            'task': 't',
            'status': 'running',
            'startedAt': 1,
          },
          {
            'id': 'a2',
            'type': 'head',
            'task': 't',
            'status': 'running',
            'startedAt': 2,
          },
          {
            'id': 'a3',
            'type': 'head',
            'task': 't',
            'status': 'done',
            'startedAt': 3,
          },
        ],
      });
      await tester.pumpWidget(app([s]));
      await settle(tester);
      await openDrawer(tester);
      final row = find.byKey(const ValueKey('row-a'));
      expect(
        find.descendant(of: row, matching: find.byType(CrabIcon)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('alpha')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('2 working  ·  \$1.20')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('running')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'the office has a screen-reader label with the title and the number of working agents',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app([session('a', 'alpha')]));
      await settle(tester);
      expect(
        find.bySemanticsLabel(RegExp('Office of alpha, 1 agents working')),
        findsOneWidget,
      );
      handle.dispose();
    },
  );

  AskInfo pendingAsk(String id, {String status = 'pending'}) => parseAsks({
    's1': {
      id: {
        'v': 1,
        'tool': 'Bash',
        'detail': 'rm -rf build',
        'why': 'deletes files',
        'session': 'alpha',
        'createdAt': serverNow,
        'status': status,
      },
    },
  }).single;

  testWidgets(
    'a new pending question pops up once, and Accept answers it and closes the pop-up',
    (tester) async {
      final answered = <String>[];
      await tester.pumpWidget(
        app(
          [session('a', 'alpha')],
          asks: [pendingAsk('k1')],
          onAnswer: (a, allow) async => answered.add('${a.id}:$allow'),
        ),
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('ask-accept')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('ask-accept')));
      await settle(tester);
      expect(answered, ['k1:true']);
      expect(find.byKey(const ValueKey('ask-accept')), findsNothing);
    },
  );

  testWidgets(
    'the pop-up closes by itself when the question is answered elsewhere, and a dismissed one does not come back',
    (tester) async {
      Widget build(List<AskInfo> asks) =>
          app([session('a', 'alpha')], asks: asks);
      await tester.pumpWidget(build([pendingAsk('k1')]));
      await settle(tester);
      expect(find.byKey(const ValueKey('ask-deny')), findsOneWidget);
      await tester.pumpWidget(build([pendingAsk('k1', status: 'expired')]));
      await settle(tester);
      expect(find.byKey(const ValueKey('ask-deny')), findsNothing);
      await tester.pumpWidget(build([pendingAsk('k2')]));
      await settle(tester);
      expect(find.byKey(const ValueKey('ask-deny')), findsOneWidget);
      await tester.tapAt(
        const Offset(5, 5),
      ); // outside the pop-up: dismissed, still open in Alerts
      await settle(tester);
      expect(find.byKey(const ValueKey('ask-deny')), findsNothing);
      await tester.pumpWidget(build([pendingAsk('k2')]));
      await settle(tester);
      expect(find.byKey(const ValueKey('ask-deny')), findsNothing);
      expect(find.byKey(const ValueKey('alert-badge')), findsOneWidget);
    },
  );

  testWidgets(
    'a question still marked pending long after it was asked is stale: no pop-up, no badge',
    (tester) async {
      final stale = parseAsks({
        's1': {
          'k9': {
            'v': 1,
            'tool': 'Bash',
            'detail': 'x',
            'session': 'alpha',
            'createdAt': serverNow - 700000,
            'status': 'pending',
          },
        },
      });
      await tester.pumpWidget(app([session('a', 'alpha')], asks: stale));
      await settle(tester);
      expect(find.byKey(const ValueKey('ask-deny')), findsNothing);
      expect(find.byKey(const ValueKey('alert-badge')), findsNothing);
    },
  );

  testWidgets(
    'an answer that cannot be sent says so, and the question stays open',
    (tester) async {
      await tester.pumpWidget(
        app(
          [session('a', 'alpha')],
          asks: [pendingAsk('k1')],
          onAnswer: (a, allow) async => throw Exception('permission denied'),
        ),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('ask-accept')));
      await settle(tester);
      expect(find.textContaining('could not be sent'), findsOneWidget);
      await tester.pump(
        const Duration(seconds: 6),
      ); // the message covers the tab bar until it fades
      await tester.pump(const Duration(seconds: 1));
      await tester.tap(find.byKey(const ValueKey('tab-2')));
      await settle(tester);
      expect(find.byKey(const ValueKey('alert-accept-k1')), findsOneWidget);
    },
  );

  testWidgets(
    'after answering in Alerts the buttons give way to Sending, so the answer cannot be changed',
    (tester) async {
      final answered = <String>[];
      await tester.pumpWidget(
        app(
          [session('a', 'alpha')],
          asks: [pendingAsk('k1')],
          onAnswer: (a, allow) async => answered.add('${a.id}:$allow'),
        ),
      );
      await settle(tester);
      await tester.tapAt(const Offset(5, 5)); // dismiss the pop-up
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('tab-2')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('alert-deny-k1')));
      await settle(tester);
      expect(answered, ['k1:false']);
      expect(find.byKey(const ValueKey('alert-accept-k1')), findsNothing);
      expect(find.textContaining('Answer sent'), findsOneWidget);
    },
  );

  testWidgets('the pop-up closing by itself leaves another open page alone', (
    tester,
  ) async {
    Widget build(List<AskInfo> asks) =>
        app([session('a', 'alpha')], asks: asks);
    await tester.pumpWidget(build(const []));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('tab-3')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('app-ask')));
    await tester.pumpWidget(build([pendingAsk('k1')]));
    await settle(tester);
    await tester.pumpWidget(build([pendingAsk('k1', status: 'allowed')]));
    await settle(tester);
    expect(find.byKey(const ValueKey('ask-deny')), findsNothing);
    expect(
      find.byKey(const ValueKey('tab-3')),
      findsOneWidget,
    ); // the page underneath is still there
  });

  CmdInfo qcmd(
    String id, {
    String sk = 'a',
    String status = 'queued',
    int at = serverNow,
  }) => CmdInfo(
    sessionKey: sk,
    id: id,
    target: 'main',
    text: 'text $id',
    createdAt: at,
    status: status,
  );

  testWidgets(
    'the Office tab has the prompt box, and the Agents tab does not',
    (tester) async {
      await tester.pumpWidget(app([session('a', 'alpha')]));
      await settle(tester);
      expect(find.byKey(const ValueKey('cmd-chip-all')), findsOneWidget);
      expect(find.byKey(const ValueKey('cmd-chip-coder-low')), findsOneWidget);
      final box = tester.getRect(find.byKey(const ValueKey('box-field')));
      final tabs = tester.getRect(find.byKey(const ValueKey('tab-0')));
      expect(box.bottom, lessThanOrEqualTo(tabs.top));
      await tester.tap(find.byKey(const ValueKey('tab-1')));
      await settle(tester);
      expect(find.byKey(const ValueKey('box-field')), findsNothing);
    },
  );

  testWidgets('typing and Send reports the selected session, target and text', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      app([
        session('a', 'alpha'),
      ], onSendCmd: (sk, t, x, {quick}) async => calls.add('$sk|$t|$x|$quick')),
    );
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('box-field')), 'hi');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('box-send')));
    await settle(tester);
    expect(calls, ['a|all|hi|null']);
  });

  testWidgets('switch off and offline each disable the box with a reason', (
    tester,
  ) async {
    await tester.pumpWidget(app([session('a', 'alpha')], appCmd: false));
    await settle(tester);
    expect(find.text('Turn on instructions in Settings'), findsOneWidget);
    await tester.pumpWidget(
      app([session('a', 'alpha', seenAt: 900000)], appCmd: true),
    );
    await settle(tester);
    expect(find.text('This session is offline'), findsOneWidget);
  });

  testWidgets(
    'eight fresh queued commands of this session block a ninth; other sessions and stale ones do not count',
    (tester) async {
      final others = [
        for (var i = 0; i < 3; i++) qcmd('o$i', sk: 'zzz'),
        for (var i = 0; i < 3; i++) qcmd('s$i', at: serverNow - 700000),
      ];
      final eight = [for (var i = 0; i < 8; i++) qcmd('q$i')];
      await tester.pumpWidget(
        app([session('a', 'alpha')], cmds: [...eight.take(5), ...others]),
      );
      await settle(tester);
      expect(find.textContaining('already waiting'), findsNothing);
      await tester.pumpWidget(
        app([session('a', 'alpha')], cmds: [...eight, ...others]),
      );
      await settle(tester);
      expect(
        find.textContaining('8 instructions are already waiting'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'tapping an agent chip opens its sheet and the close button closes it',
    (tester) async {
      await tester.pumpWidget(
        app([session('a', 'alpha')], cmds: [qcmd('c1', status: 'delivered')]),
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('sheet-close')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('cmd-chip-coder-low')));
      await settle(tester);
      expect(find.byKey(const ValueKey('sheet-close')), findsOneWidget);
      expect(find.text('Delivered through the main agent'), findsOneWidget);
      expect(find.byKey(const ValueKey('cmd-row-c1')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sheet-close')));
      await settle(tester);
      expect(find.byKey(const ValueKey('sheet-close')), findsNothing);
    },
  );

  testWidgets('a quick button in the sheet sends to the chosen target', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      app([
        session('a', 'alpha'),
      ], onSendCmd: (sk, t, x, {quick}) async => calls.add('$sk|$t|$x|$quick')),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('cmd-chip-main')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('sheet-quick-pause')));
    await settle(tester);
    expect(calls, ['a|main|please pause after the current step|pause']);
  });

  testWidgets('the Settings tab switch reports the new value', (tester) async {
    final seen = <bool>[];
    await tester.pumpWidget(
      app([session('a', 'alpha')], appCmd: false, onAppCmdChanged: seen.add),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('tab-3')));
    await settle(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('app-cmd')));
    await tester.tap(find.byKey(const ValueKey('app-cmd')));
    await tester.pump();
    expect(seen, [true]);
  });
}
