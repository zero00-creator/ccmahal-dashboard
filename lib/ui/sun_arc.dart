import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../environment.dart';
import '../theme/tokens.dart';
import 'glass.dart';

/// A small arc with the sun by day or the moon by night, and the time under
/// it: it shows at a glance that the office follows the clock.
class SunArc extends StatelessWidget {
  const SunArc({super.key, required this.env, required this.timeLabel});

  final Environment env;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final style = GlassScope.maybeOf(context) ?? glassFor(env.dayness);
    return Semantics(
      label: 'Time of day, $timeLabel',
      child: SizedBox(
        width: 96,
        height: 44,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Expanded(
              child: CustomPaint(
                size: const Size(96, 30),
                painter: _ArcPainter(env: env, line: style.inkMuted),
              ),
            ),
            Text(
              timeLabel,
              style: TextStyle(
                fontSize: 11,
                color: style.inkMuted,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ArcPainter extends CustomPainter {
  _ArcPainter({required this.env, required this.line});

  final Environment env;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(4, 4, size.width - 8, (size.height - 4) * 2);
    final base = size.height;
    canvas.drawArc(
      rect,
      math.pi,
      math.pi,
      false,
      Paint()
        ..color = line.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    canvas.drawLine(
      Offset(0, base),
      Offset(size.width, base),
      Paint()
        ..color = line.withValues(alpha: 0.5)
        ..strokeWidth = 1,
    );
    final isDay = env.dayness >= 0.5;
    final f = isDay ? env.sun : env.moon;
    final ang = math.pi * (1 - f);
    final c = Offset(
      size.width / 2 + (size.width / 2 - 4) * math.cos(ang),
      base - (base - 4) * math.sin(ang),
    );
    if (isDay) {
      canvas.drawCircle(c, 6, Paint()..color = const Color(0xFFFFD34E));
    } else {
      canvas.drawCircle(c, 6, Paint()..color = const Color(0xFFF4F1D0));
      canvas.drawCircle(
        c + const Offset(3, -3),
        5,
        Paint()..color = const Color(0xFF2B3A78),
      );
    }
  }

  @override
  bool shouldRepaint(_ArcPainter old) =>
      old.env.dayness != env.dayness ||
      old.env.sun != env.sun ||
      old.env.moon != env.moon;
}
