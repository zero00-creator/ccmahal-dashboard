import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Spacing scale (logical px). Density dial 6 of 10: a 4-based scale with
/// room to breathe around the glass, tight inside chips and rows.
class Space {
  static const double x1 = 4, x2 = 8, x3 = 12, x4 = 16, x5 = 24, x6 = 32;
}

class Radii {
  static const double chip = 14, card = 28, sheet = 36;
}

/// The smallest touch target (logical px).
const double minTap = 44;

/// The desktop layout starts at this available width (logical px); below it
/// the phone layout is used.
const double wideBreakpoint = 900;

/// Desktop layout: the sessions column, the right column and the widest
/// permission pop-up.
const double sessionsPanelWidth = 280;
const double sidePanelWidth = 380;
const double askDialogMaxWidth = 480;

/// The right column grows from 380 to 440 px on windows 1600 px wide or more.
double sidePanelWidthFor(double windowWidth) =>
    windowWidth >= 1600 ? 440 : sidePanelWidth;

/// The one factor that scales desktop text above 1400 px (1.0 up to 1400,
/// then modestly more, at most 1.25).
double uiScaleFor(double windowWidth) => windowWidth <= 1400
    ? 1.0
    : (1 + (windowWidth - 1400) / 2000).clamp(1.0, 1.25);

/// How a glass panel looks at one hour of the day.
class GlassStyle {
  const GlassStyle({
    required this.tint,
    required this.blur,
    required this.border,
    required this.ink,
    required this.inkMuted,
    required this.accent,
    required this.error,
  });

  final Color tint;
  final double blur;
  final Color border;
  final Color ink;
  final Color inkMuted;
  final Color accent;
  final Color error;

  static GlassStyle lerp(GlassStyle a, GlassStyle b, double t) => GlassStyle(
    tint: Color.lerp(a.tint, b.tint, t)!,
    blur: a.blur + (b.blur - a.blur) * t,
    border: Color.lerp(a.border, b.border, t)!,
    ink: Color.lerp(a.ink, b.ink, t)!,
    inkMuted: Color.lerp(a.inkMuted, b.inkMuted, t)!,
    accent: Color.lerp(a.accent, b.accent, t)!,
    error: Color.lerp(a.error, b.error, t)!,
  );
}

const GlassStyle _dayGlass = GlassStyle(
  tint: Color(0x99FFFFFF), // white at 60%: readable over any backdrop
  blur: 14,
  border: Color(0x66FFFFFF),
  ink: Color(0xFF1C1C1E),
  inkMuted: Color(0xFF24252B),
  accent: Color(0xFFC2410C),
  error: Color(0xFF7A1410),
);

const GlassStyle _nightGlass = GlassStyle(
  tint: Color(0xC7181C38), // deep indigo at 78%
  blur: 18,
  border: Color(0x38FFFFFF),
  ink: Color(0xFFF5F5FA),
  inkMuted: Color(0xFFD5DAEB),
  accent: Color(0xFFFFB86B),
  error: Color(0xFFFFB4AB),
);

/// The glass style for a time of day. It switches at dayness 0.5 so text
/// never sits at mid contrast; the panel animates the switch (see GlassPanel).
GlassStyle glassFor(double dayness) => dayness >= 0.5 ? _dayGlass : _nightGlass;

double _channel(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _luminance(Color c) =>
    0.2126 * _channel(c.r) + 0.7152 * _channel(c.g) + 0.0722 * _channel(c.b);

/// WCAG contrast ratio of two opaque colours (1 to 21).
double contrastRatio(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}
