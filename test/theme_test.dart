import 'package:ccmahal_dashboard/theme/motion.dart';
import 'package:ccmahal_dashboard/theme/tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ink and muted ink on glass reach 4.5:1 at every dayness over the worst backdrops (white, black, deep night blue)', () {
    const worst = [Color(0xFFFFFFFF), Color(0xFF000000), Color(0xFF0B1238)];
    for (final d in [0.0, 0.25, 0.49, 0.5, 0.75, 1.0]) {
      final style = glassFor(d);
      for (final backdrop in worst) {
        final glass = Color.alphaBlend(style.tint, backdrop);
        expect(
          contrastRatio(style.ink, glass),
          greaterThanOrEqualTo(4.5),
          reason: 'ink at dayness $d over $backdrop',
        );
        expect(
          contrastRatio(style.inkMuted, glass),
          greaterThanOrEqualTo(4.5),
          reason: 'muted ink at dayness $d over $backdrop',
        );
      }
    }
  });

  test('error text reaches 4.5:1 on the glass of its own time of day', () {
    // Day glass is used only in daylight, so its worst backdrops are white and mid grey; night glass faces all three.
    final byDayness = {
      0.0: [Color(0xFFFFFFFF), Color(0xFF000000), Color(0xFF0B1238)],
      0.49: [Color(0xFFFFFFFF), Color(0xFF000000), Color(0xFF0B1238)],
      0.5: [Color(0xFFFFFFFF), Color(0xFF808080)],
      1.0: [Color(0xFFFFFFFF), Color(0xFF808080)],
    };
    byDayness.forEach((d, backdrops) {
      final style = glassFor(d);
      for (final b in backdrops) {
        expect(
          contrastRatio(style.error, Color.alphaBlend(style.tint, b)),
          greaterThanOrEqualTo(4.5),
          reason: 'error at dayness $d over $b',
        );
      }
    });
  });

  test('contrastRatio is 21 for black on white and 1 for equal colours', () {
    expect(contrastRatio(Colors.black, Colors.white), closeTo(21, 0.01));
    expect(contrastRatio(Colors.red, Colors.red), closeTo(1, 0.001));
  });

  test('Space values are strictly increasing', () {
    final v = [Space.x1, Space.x2, Space.x3, Space.x4, Space.x5, Space.x6];
    for (var i = 1; i < v.length; i++) {
      expect(v[i], greaterThan(v[i - 1]));
    }
  });

  test('Motion durations: quick < standard < slow and slow <= 400 ms', () {
    expect(Motion.quick, lessThan(Motion.standard));
    expect(Motion.standard, lessThan(Motion.slow));
    expect(Motion.slow, lessThanOrEqualTo(const Duration(milliseconds: 400)));
  });

  testWidgets('Motion.scaled returns zero when animations are disabled', (
    tester,
  ) async {
    Duration? plain;
    Duration? reduced;
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: Builder(
          builder: (c) {
            reduced = Motion.scaled(c, Motion.standard);
            return const SizedBox();
          },
        ),
      ),
    );
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(),
        child: Builder(
          builder: (c) {
            plain = Motion.scaled(c, Motion.standard);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(reduced, Duration.zero);
    expect(plain, Motion.standard);
  });
}
