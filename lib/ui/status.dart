import 'package:flutter/material.dart';

/// The colour of a session or agent status word.
Color statusColor(String status) {
  switch (status) {
    case 'running':
      return const Color(0xFF3DDC84);
    case 'idle':
      return const Color(0xFF8E929A);
    case 'offline':
      return const Color(0xFFE0A526);
    case 'failed':
      return const Color(0xFFE5484D);
    default:
      return const Color(0xFF5B6270);
  }
}

String money(double? v) =>
    v == null ? '-' : '\$${v.toStringAsFixed(v >= 100 ? 0 : 2)}';
