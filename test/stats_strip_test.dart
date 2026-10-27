import 'package:ccmahal_dashboard/environment.dart';
import 'package:ccmahal_dashboard/models.dart';
import 'package:ccmahal_dashboard/theme/tokens.dart';
import 'package:ccmahal_dashboard/ui/stats_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

SessionInfo session(Map<String, dynamic> extra) => SessionInfo.fromMap('k', {
  'project': 'p',
  'status': 'running',
  'seenAt': 988000,
  ...extra,
});

Widget host(
  SessionInfo s, {
  DateTime? at,
  double scale = 1,
  int now = 1000000,
}) => MaterialApp(
  home: Scaffold(
    body: StatsStrip(
      session: s,
      serverNow: now,
      env: environmentAt(at ?? DateTime(2026, 10, 26, 12)),
      scale: scale,
    ),
  ),
);

Map<String, dynamic> agentMap(String id, String status) => {
  'id': id,
  'type': 't',
  'task': 'x',
  'status': status,
  'startedAt': 1,
};

void main() {
  testWidgets('shows working/total, cost, context fill and last seen', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        session({
          'agents': [
            agentMap('a', 'running'),
            agentMap('b', 'done'),
            agentMap('c', 'running'),
          ],
          'meter': {'costUsd': 1.5, 'ctxPct': 42},
        }),
      ),
    );
    expect(find.text('2/3 working'), findsOneWidget);
    expect(find.text('\$1.50'), findsOneWidget);
    expect(find.text('context 42%'), findsOneWidget);
    expect(find.text('seen 12s ago'), findsOneWidget);
  });

  testWidgets('omits a value that is missing', (tester) async {
    await tester.pumpWidget(host(session({'seenAt': 0})));
    expect(find.byKey(const ValueKey('stat-agents')), findsNothing);
    expect(find.byKey(const ValueKey('stat-cost')), findsNothing);
    expect(find.byKey(const ValueKey('stat-ctx')), findsNothing);
    expect(find.byKey(const ValueKey('stat-seen')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('cost alone shows only the cost', (tester) async {
    await tester.pumpWidget(
      host(
        session({
          'seenAt': 0,
          'meter': {'costUsd': 12.0},
        }),
      ),
    );
    expect(find.byKey(const ValueKey('stat-cost')), findsOneWidget);
    expect(find.byKey(const ValueKey('stat-ctx')), findsNothing);
    expect(find.byKey(const ValueKey('stat-agents')), findsNothing);
  });

  testWidgets('last seen counts minutes and hours; ended says ended', (
    tester,
  ) async {
    await tester.pumpWidget(host(session({'seenAt': 1000000 - 5 * 60000})));
    expect(find.text('seen 5m ago'), findsOneWidget);
    await tester.pumpWidget(
      host(session({'seenAt': 20000000 - 3 * 3600000}), now: 20000000),
    );
    expect(find.text('seen 3h ago'), findsOneWidget);
    await tester.pumpWidget(host(session({'status': 'ended'})));
    expect(find.text('ended'), findsOneWidget);
  });

  testWidgets('text keeps contrast with the glass at day and at night', (
    tester,
  ) async {
    for (final h in [12, 22]) {
      await tester.pumpWidget(
        host(
          session({
            'agents': [agentMap('a', 'running')],
          }),
          at: DateTime(2026, 10, 26, h),
        ),
      );
      await tester.pumpAndSettle();
      final t = tester.widget<Text>(find.text('1/1 working'));
      final style = glassFor(environmentAt(DateTime(2026, 10, 26, h)).dayness);
      expect(t.style?.color, style.ink);
      expect(
        contrastRatio(
          style.ink,
          Color.alphaBlend(style.tint, const Color(0xFF808080)),
        ),
        greaterThan(4.5),
      );
    }
  });

  testWidgets('scale grows the text', (tester) async {
    final s = session({
      'agents': [agentMap('a', 'running')],
    });
    await tester.pumpWidget(host(s));
    final small = tester
        .widget<Text>(find.text('1/1 working'))
        .style!
        .fontSize!;
    await tester.pumpWidget(host(s, scale: 1.25));
    final big = tester.widget<Text>(find.text('1/1 working')).style!.fontSize!;
    expect(big, closeTo(small * 1.25, 0.01));
  });
}
