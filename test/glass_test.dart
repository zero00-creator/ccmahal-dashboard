import 'package:ccmahal_dashboard/environment.dart';
import 'package:ccmahal_dashboard/theme/tokens.dart';
import 'package:ccmahal_dashboard/ui/glass.dart';
import 'package:ccmahal_dashboard/ui/sun_arc.dart';
import 'package:ccmahal_dashboard/ui/top_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Environment at(int h, int m) => environmentAt(DateTime(2026, 10, 26, h, m));

Widget host(Widget child, {double width = 360, bool reduced = false}) =>
    MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: Scaffold(
          body: Center(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    );

void main() {
  testWidgets('GlassPanel shows its child with and without blur', (
    tester,
  ) async {
    for (final blur in [true, false]) {
      await tester.pumpWidget(
        host(
          GlassPanel(
            style: glassFor(1),
            blurEnabled: blur,
            child: const Text('hello'),
          ),
        ),
      );
      expect(find.text('hello'), findsOneWidget);
      expect(find.byType(BackdropFilter), blur ? findsOneWidget : findsNothing);
    }
  });

  testWidgets(
    'GlassPanel animates to a new style over Motion.slow, and at once when animations are off',
    (tester) async {
      Future<Color> tintAfter(Duration d, bool reduced) async {
        await tester.pumpWidget(
          host(
            GlassPanel(style: glassFor(1), child: const SizedBox(height: 20)),
            reduced: reduced,
          ),
        );
        await tester.pumpWidget(
          host(
            GlassPanel(style: glassFor(0), child: const SizedBox(height: 20)),
            reduced: reduced,
          ),
        );
        await tester.pump(d);
        final box = tester.widget<DecoratedBox>(
          find.byKey(const ValueKey('glass-tint')),
        );
        return (box.decoration as BoxDecoration).color!;
      }

      final start = glassFor(1).tint;
      final end = glassFor(0).tint;
      final mid = await tintAfter(const Duration(milliseconds: 100), false);
      expect(mid, isNot(start));
      expect(mid, isNot(end));
      final done = await tintAfter(const Duration(milliseconds: 500), false);
      expect(done, end);
      final instant = await tintAfter(Duration.zero, true);
      expect(instant, end);
    },
  );

  testWidgets(
    'TopCard shows the title and subtitle and calls onMenu when the menu button is tapped',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        host(
          TopCard(
            title: 'my-mod',
            subtitle: 'Noon  ·  3 working',
            env: at(12, 0),
            timeLabel: '12:00',
            onMenu: () => taps++,
          ),
        ),
      );
      expect(find.text('my-mod'), findsOneWidget);
      expect(find.text('Noon  ·  3 working'), findsOneWidget);
      await tester.tap(find.byTooltip('Sessions'));
      expect(taps, 1);
    },
  );

  testWidgets('the menu button is at least 44 x 44', (tester) async {
    await tester.pumpWidget(
      host(
        TopCard(
          title: 't',
          subtitle: 's',
          env: at(12, 0),
          timeLabel: '12:00',
          onMenu: () {},
        ),
      ),
    );
    final size = tester.getSize(find.byTooltip('Sessions'));
    expect(size.width, greaterThanOrEqualTo(minTap));
    expect(size.height, greaterThanOrEqualTo(minTap));
  });

  testWidgets('the menu button has a semantics label', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      host(
        TopCard(
          title: 't',
          subtitle: 's',
          env: at(12, 0),
          timeLabel: '12:00',
          onMenu: () {},
        ),
      ),
    );
    expect(find.bySemanticsLabel('Sessions'), findsWidgets);
    handle.dispose();
  });

  testWidgets(
    'a 200-character title is ellipsized to one line without overflow',
    (tester) async {
      await tester.pumpWidget(
        host(
          TopCard(
            title: 'x' * 200,
            subtitle: 'y' * 200,
            env: at(12, 0),
            timeLabel: '12:00',
            onMenu: () {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final text = tester.widget<Text>(find.text('x' * 200));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    },
  );

  testWidgets('SunArc paints for dawn, day, dusk and night without error', (
    tester,
  ) async {
    for (final (h, m) in [(7, 0), (12, 0), (18, 30), (21, 41), (3, 0)]) {
      await tester.pumpWidget(host(SunArc(env: at(h, m), timeLabel: '$h:$m')));
      expect(tester.takeException(), isNull);
      expect(find.byType(SunArc), findsOneWidget);
    }
  });

  testWidgets(
    'the card text follows the fade: mid-fade it is neither the old nor the new ink',
    (tester) async {
      Future<Color> titleColor(Duration after) async {
        await tester.pumpWidget(
          host(
            TopCard(
              title: 'name',
              subtitle: 's',
              env: at(12, 0),
              timeLabel: '12:00',
              onMenu: () {},
            ),
          ),
        );
        await tester.pumpWidget(
          host(
            TopCard(
              title: 'name',
              subtitle: 's',
              env: at(23, 0),
              timeLabel: '23:00',
              onMenu: () {},
            ),
          ),
        );
        await tester.pump(after);
        return tester.widget<Text>(find.text('name')).style!.color ??
            DefaultTextStyle.of(tester.element(find.text('name'))).style.color!;
      }

      final oldInk = glassFor(1).ink;
      final newInk = glassFor(0).ink;
      final mid = await titleColor(const Duration(milliseconds: 120));
      expect(mid, isNot(oldInk));
      expect(mid, isNot(newInk));
      final done = await titleColor(const Duration(milliseconds: 600));
      expect(done, newInk);
    },
  );
}
