import 'package:flutter/widgets.dart';

/// Motion tokens (motion dial 7 of 10): short, purposeful, never decorative
/// loops. Everything goes through [scaled] so reduced motion means none.
class Motion {
  static const Duration quick = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 220);
  static const Duration slow = Duration(milliseconds: 360);

  static const Curve out = Curves.easeOutCubic;

  /// A gentle overshoot for panels that settle into place.
  static const Curve spring = Cubic(0.2, 0.9, 0.3, 1.08);

  /// [d], or zero when the person turned animations off.
  static Duration scaled(BuildContext context, Duration d) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;
}
