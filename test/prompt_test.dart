import 'package:ccmahal_dashboard/auth/auth_service.dart';
import 'package:ccmahal_dashboard/cmds.dart';
import 'package:ccmahal_dashboard/models.dart';
import 'package:ccmahal_dashboard/theme/tokens.dart';
import 'package:ccmahal_dashboard/ui/prompt_box.dart';
import 'package:ccmahal_dashboard/ui/settings_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

AgentInfo agent(int i, String type) => AgentInfo(
  id: 'a$i',
  type: type,
  task: 't',
  model: 'm',
  status: 'running',
  startedAt: i,
  costUsd: 0,
  stepNote: 'writing tests',
);

CmdInfo cmd(
  String id, {
  String status = 'queued',
  int at = 1000,
  String target = 'main',
  String text = 'hello',
  String? note,
}) => CmdInfo(
  sessionKey: 's1',
  id: id,
  target: target,
  text: text,
  createdAt: at,
  status: status,
  note: note,
);

Widget host(Widget child, {double width = 400, double height = 800}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(size: Size(width, height)),
        child: Scaffold(
          body: SizedBox(
            width: width,
            height: height,
            child: Align(alignment: Alignment.bottomCenter, child: child),
          ),
        ),
      ),
    );

typedef Sent = List<String>;

void main() {
  final style = glassFor(1);

  Widget box({
    List<AgentInfo>? agents,
    String target = 'all',
    ValueChanged<String>? onTarget,
    bool appCmd = true,
    bool offline = false,
    int queued = 0,
    CmdSend? onSend,
    CmdInfo? last,
  }) => host(
    PromptBox(
      agents:
          agents ??
          [agent(1, 'coder-low'), agent(2, 'coder-low'), agent(3, 'debugger')],
      target: target,
      onTarget: onTarget ?? (_) {},
      style: style,
      appCmd: appCmd,
      offline: offline,
      queued: queued,
      onSend: onSend ?? (t, x, {quick}) async {},
      last: last,
      blurEnabled: false,
    ),
  );

  FilledButton sendButton(WidgetTester tester, String key) =>
      tester.widget<FilledButton>(find.byKey(ValueKey(key)));

  testWidgets(
    'the strip has All, Main, then each agent type once, 44 px high',
    (tester) async {
      final got = <String>[];
      await tester.pumpWidget(box(onTarget: got.add));
      expect(find.byKey(const ValueKey('cmd-chip-all')), findsOneWidget);
      expect(find.byKey(const ValueKey('cmd-chip-main')), findsOneWidget);
      expect(find.byKey(const ValueKey('cmd-chip-coder-low')), findsOneWidget);
      expect(find.byKey(const ValueKey('cmd-chip-debugger')), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Main'), findsOneWidget);
      for (final k in ['all', 'main', 'coder-low', 'debugger']) {
        expect(
          tester.getSize(find.byKey(ValueKey('cmd-chip-$k'))).height,
          greaterThanOrEqualTo(minTap),
          reason: k,
        );
      }
      final all = tester.getTopLeft(find.byKey(const ValueKey('cmd-chip-all')));
      final main = tester.getTopLeft(
        find.byKey(const ValueKey('cmd-chip-main')),
      );
      final first = tester.getTopLeft(
        find.byKey(const ValueKey('cmd-chip-coder-low')),
      );
      expect(all.dx, lessThan(main.dx));
      expect(main.dx, lessThan(first.dx));
      await tester.ensureVisible(
        find.byKey(const ValueKey('cmd-chip-debugger')),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cmd-chip-debugger')));
      await tester.ensureVisible(find.byKey(const ValueKey('cmd-chip-main')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('cmd-chip-main')));
      expect(got, ['debugger', 'main']);
    },
  );

  testWidgets('Send is 44 px high and sends the trimmed text to the target', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      box(
        target: 'main',
        onSend: (t, x, {quick}) async => calls.add('$t|$x|$quick'),
      ),
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('box-send'))).height,
      greaterThanOrEqualTo(minTap),
    );
    expect(sendButton(tester, 'box-send').onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('box-field')), '  hi  ');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('box-send')));
    await tester.pump();
    expect(calls, ['main|hi|null']);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('box-field')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('with the switch off Send is disabled and the reason is shown', (
    tester,
  ) async {
    await tester.pumpWidget(box(appCmd: false));
    await tester.enterText(find.byKey(const ValueKey('box-field')), 'hi');
    await tester.pump();
    expect(find.text('Turn on instructions in Settings'), findsOneWidget);
    expect(sendButton(tester, 'box-send').onPressed, isNull);
  });

  testWidgets('an offline session disables Send and says why', (tester) async {
    await tester.pumpWidget(box(offline: true));
    await tester.enterText(find.byKey(const ValueKey('box-field')), 'hi');
    await tester.pump();
    expect(find.text('This session is offline'), findsOneWidget);
    expect(sendButton(tester, 'box-send').onPressed, isNull);
  });

  testWidgets('empty or over 500 characters disables Send; 500 is fine', (
    tester,
  ) async {
    await tester.pumpWidget(box());
    expect(sendButton(tester, 'box-send').onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('box-field')), '   ');
    await tester.pump();
    expect(sendButton(tester, 'box-send').onPressed, isNull);
    await tester.enterText(find.byKey(const ValueKey('box-field')), 'a' * 501);
    await tester.pump();
    expect(sendButton(tester, 'box-send').onPressed, isNull);
    expect(find.textContaining('500'), findsWidgets);
    await tester.enterText(find.byKey(const ValueKey('box-field')), 'a' * 500);
    await tester.pump();
    expect(sendButton(tester, 'box-send').onPressed, isNotNull);
  });

  testWidgets('eight queued disables Send and says so', (tester) async {
    await tester.pumpWidget(box(queued: 8));
    await tester.enterText(find.byKey(const ValueKey('box-field')), 'hi');
    await tester.pump();
    expect(
      find.textContaining('8 instructions are already waiting'),
      findsOneWidget,
    );
    expect(sendButton(tester, 'box-send').onPressed, isNull);
  });

  testWidgets('a failed send shows an error and keeps the text', (
    tester,
  ) async {
    await tester.pumpWidget(
      box(onSend: (t, x, {quick}) async => throw Exception('denied')),
    );
    await tester.enterText(find.byKey(const ValueKey('box-field')), 'keep me');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('box-send')));
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const ValueKey('box-error')), findsOneWidget);
    expect(find.textContaining('could not be sent'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('box-field')))
          .controller!
          .text,
      'keep me',
    );
  });

  testWidgets('the last command is shown with its state word and note', (
    tester,
  ) async {
    await tester.pumpWidget(
      box(
        last: cmd('c1', status: 'failed', note: 'too old', text: 'go on'),
      ),
    );
    final line = tester.widget<Text>(find.byKey(const ValueKey('cmd-last')));
    expect(line.data, contains('go on'));
    expect(line.data, contains('failed'));
    expect(line.data, contains('too old'));
  });

  Widget sheet({
    String target = 'main',
    List<CmdInfo> cmds = const [],
    bool appCmd = true,
    bool offline = false,
    int queued = 0,
    CmdSend? onSend,
    VoidCallback? onClose,
  }) => host(
    AgentSheet(
      target: target,
      status: 'running · writing tests',
      cmds: cmds,
      style: style,
      appCmd: appCmd,
      offline: offline,
      queued: queued,
      onSend: onSend ?? (t, x, {quick}) async {},
      onClose: onClose ?? () {},
      blurEnabled: false,
    ),
  );

  testWidgets(
    'the main sheet shows status, four quick buttons and no via line',
    (tester) async {
      await tester.pumpWidget(sheet());
      expect(find.text('Main'), findsWidgets);
      expect(find.textContaining('writing tests'), findsOneWidget);
      for (final t in [
        'Ask to pause',
        'Ask to continue',
        'Ask to stop',
        'Report status',
      ]) {
        expect(find.text(t), findsOneWidget, reason: t);
      }
      for (final q in ['pause', 'continue', 'stop', 'status']) {
        expect(
          tester.getSize(find.byKey(ValueKey('sheet-quick-$q'))).height,
          greaterThanOrEqualTo(minTap),
          reason: q,
        );
      }
      expect(find.text('Delivered through the main agent'), findsNothing);
      expect(find.byKey(const ValueKey('sheet-field')), findsOneWidget);
      expect(find.byKey(const ValueKey('sheet-send')), findsOneWidget);
    },
  );

  testWidgets('an agent sheet says it is delivered through the main agent', (
    tester,
  ) async {
    await tester.pumpWidget(sheet(target: 'debugger'));
    expect(find.text('Delivered through the main agent'), findsOneWidget);
    expect(find.text('debugger'), findsWidgets);
  });

  testWidgets('a quick button sends the canned action to the target', (
    tester,
  ) async {
    final calls = <String>[];
    await tester.pumpWidget(
      sheet(
        target: 'all',
        onSend: (t, x, {quick}) async => calls.add('$t|$quick'),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('sheet-quick-stop')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-quick-status')));
    await tester.pump();
    expect(calls, ['all|stop', 'all|status']);
  });

  testWidgets(
    'quick buttons are disabled with the reason when the switch is off',
    (tester) async {
      final calls = <String>[];
      await tester.pumpWidget(
        sheet(appCmd: false, onSend: (t, x, {quick}) async => calls.add(t)),
      );
      expect(find.text('Turn on instructions in Settings'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sheet-quick-pause')));
      await tester.pump();
      expect(calls, isEmpty);
    },
  );

  testWidgets('the sheet text box sends and offline blocks it', (tester) async {
    final calls = <String>[];
    await tester.pumpWidget(
      sheet(onSend: (t, x, {quick}) async => calls.add('$t|$x')),
    );
    await tester.enterText(find.byKey(const ValueKey('sheet-field')), 'do it');
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('sheet-send')));
    await tester.pump();
    expect(calls, ['main|do it']);
    await tester.pumpWidget(sheet(offline: true));
    expect(find.text('This session is offline'), findsOneWidget);
    expect(sendButton(tester, 'sheet-send').onPressed, isNull);
  });

  testWidgets('the sheet lists the last 10 commands with state and note', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final cmds = [
      for (var i = 12; i >= 1; i--)
        cmd(
          'c$i',
          at: i * 1000,
          text: 'text $i',
          status: i == 12 ? 'queued' : (i == 11 ? 'failed' : 'delivered'),
          note: i == 11 ? 'too old' : null,
        ),
    ];
    await tester.pumpWidget(sheet(cmds: cmds));
    for (var i = 12; i >= 3; i--) {
      expect(find.byKey(ValueKey('cmd-row-c$i')), findsOneWidget, reason: '$i');
    }
    expect(find.byKey(const ValueKey('cmd-row-c2')), findsNothing);
    expect(find.byKey(const ValueKey('cmd-row-c1')), findsNothing);
    String rowText(String id) => tester
        .widgetList<Text>(
          find.descendant(
            of: find.byKey(ValueKey('cmd-row-$id')),
            matching: find.byType(Text),
          ),
        )
        .map((t) => t.data ?? '')
        .join(' ');
    expect(rowText('c12'), contains('queued'));
    expect(rowText('c11'), contains('failed'));
    expect(rowText('c11'), contains('too old'));
    expect(rowText('c10'), contains('delivered'));
  });

  testWidgets('the close button closes the sheet', (tester) async {
    var closed = 0;
    await tester.pumpWidget(sheet(onClose: () => closed++));
    expect(
      tester.getSize(find.byKey(const ValueKey('sheet-close'))).height,
      greaterThanOrEqualTo(minTap),
    );
    await tester.tap(find.byKey(const ValueKey('sheet-close')));
    expect(closed, 1);
  });

  testWidgets('Settings has the Send instructions switch with one help line', (
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
          appCmd: false,
          onAppCmdChanged: seen.add,
        ),
        height: 1400,
      ),
    );
    expect(find.text('Send instructions from here'), findsOneWidget);
    expect(
      find.text(
        'Lets this app type into your running Claude session. Anyone with this login can do the same.',
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('app-cmd'))).height,
      greaterThanOrEqualTo(minTap),
    );
    expect(
      tester
          .widget<SwitchListTile>(find.byKey(const ValueKey('app-cmd')))
          .value,
      isFalse,
    );
    await tester.tap(find.byKey(const ValueKey('app-cmd')));
    await tester.pump();
    expect(seen, [true]);
  });
}
