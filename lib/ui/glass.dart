import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../theme/motion.dart';
import '../theme/tokens.dart';

/// The glass style as it is right now, mid-fade included: text inside a panel
/// reads it so the ink follows the tint instead of jumping to the new colour.
class GlassScope extends InheritedWidget {
  const GlassScope({super.key, required this.style, required super.child});

  final GlassStyle style;

  static GlassStyle? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GlassScope>()?.style;

  @override
  bool updateShouldNotify(GlassScope old) => old.style != style;
}

class _StyleTween extends Tween<GlassStyle> {
  _StyleTween({required GlassStyle end}) : super(end: end);

  @override
  GlassStyle lerp(double t) => GlassStyle.lerp(begin!, end!, t);
}

/// A frosted-glass panel: a blurred backdrop, a tint, a light edge and a
/// faint highlight along the top. The tint and ink animate when the hour
/// changes the style (the switch happens at dusk and dawn).
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.style,
    required this.child,
    this.radius = Radii.card,
    this.blurEnabled = true,
    this.padding,
  });

  final GlassStyle style;
  final Widget child;
  final double radius;

  /// Off on devices where the blur costs too many frames: the panel is then
  /// a plain translucent fill with the same tint and edge.
  final bool blurEnabled;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    return TweenAnimationBuilder<GlassStyle>(
      tween: _StyleTween(end: style),
      duration: Motion.scaled(context, Motion.slow),
      curve: Motion.out,
      builder: (context, s, _) {
        Widget body = DecoratedBox(
          key: const ValueKey('glass-tint'),
          decoration: BoxDecoration(
            color: s.tint,
            borderRadius: r,
            border: Border.all(color: s.border),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.center,
              colors: [
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0),
              ],
            ),
          ),
          // A transparent Material so list tiles, buttons and ink splashes inside the glass can paint.
          child: Material(
            type: MaterialType.transparency,
            child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
          ),
        );
        if (blurEnabled) {
          body = BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: s.blur, sigmaY: s.blur),
            child: body,
          );
        }
        return RepaintBoundary(
          child: GlassScope(
            style: s,
            child: DefaultTextStyle.merge(
              style: TextStyle(color: s.ink),
              child: IconTheme(
                data: IconThemeData(color: s.ink),
                child: ClipRRect(borderRadius: r, child: body),
              ),
            ),
          ),
        );
      },
    );
  }
}
