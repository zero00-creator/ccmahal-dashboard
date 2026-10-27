import 'package:ccmahal_dashboard/environment.dart';
import 'package:flutter_test/flutter_test.dart';

Environment at(int h, int m) => environmentAt(DateTime(2026, 10, 26, h, m));

void main() {
  test('noon is full day', () {
    final e = at(12, 0);
    expect(e.dayness, 1);
    expect(e.lamps, 0);
    expect(e.stage, Stage.day);
  });

  test('21:41 is night with the lamps on', () {
    final e = at(21, 41);
    expect(e.dayness, 0);
    expect(e.lamps, 1);
    expect(e.stage, Stage.night);
  });

  test('07:00 is dawn and in between', () {
    final e = at(7, 0);
    expect(e.stage, Stage.dawn);
    expect(e.dayness, greaterThan(0));
    expect(e.dayness, lessThan(1));
    expect(e.lamps, closeTo(1 - e.dayness, 1e-9));
  });

  test('18:00 is dusk', () {
    expect(at(18, 0).stage, Stage.dusk);
  });

  test('continuous: no jump above 0.02 in dayness or lamps between adjacent minutes', () {
    var prev = at(0, 0);
    for (var t = 1; t < 1440; t++) {
      final e = at(t ~/ 60, t % 60);
      expect(
        (e.dayness - prev.dayness).abs(),
        lessThan(0.02),
        reason: 'dayness at minute $t',
      );
      expect(
        (e.lamps - prev.lamps).abs(),
        lessThan(0.02),
        reason: 'lamps at minute $t',
      );
      prev = e;
    }
  });

  test('midnight wraps: 23:59 and 00:00 are equal within 0.02', () {
    expect((at(23, 59).dayness - at(0, 0).dayness).abs(), lessThan(0.02));
    expect((at(23, 59).lamps - at(0, 0).lamps).abs(), lessThan(0.02));
  });

  test('the sun is halfway across at 12:00 and rests at the ends', () {
    expect(at(12, 0).sun, closeTo(0.5, 1e-9));
    expect(at(6, 0).sun, 0);
    expect(at(18, 0).sun, 1);
    expect(at(23, 0).sun, inInclusiveRange(0, 1));
  });

  test('the moon crosses the sky between 18:00 and 06:00', () {
    expect(at(0, 0).moon, closeTo(0.5, 1e-9));
    expect(at(18, 0).moon, 0);
  });

  test('a DateTime on a daylight-saving change day does not throw', () {
    final e = environmentAt(DateTime(2026, 3, 8, 2, 30));
    expect(e.dayness, inInclusiveRange(0, 1));
  });

  test('colours move toward the night palette as dayness falls', () {
    expect(at(12, 0).skyTop, isNot(at(21, 41).skyTop));
    expect(at(21, 41).ambient.a, greaterThan(at(12, 0).ambient.a));
  });
}
