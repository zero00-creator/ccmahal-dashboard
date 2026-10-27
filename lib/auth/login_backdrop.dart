import 'package:flutter/material.dart';

import '../environment.dart';
import '../models.dart';
import '../office/office_view.dart';
import '../sprites.dart';

/// The room behind the login card: the same pixel office, with a few crabs
/// resting, lit by the phone's own clock.
class LoginBackdrop extends StatelessWidget {
  const LoginBackdrop({super.key, required this.sprites, required this.now});

  final SpriteSet sprites;
  final DateTime now;

  static SessionInfo demo(int nowMs) => SessionInfo.fromMap('demo', {
    'project': 'CCmahal',
    'title': 'CCmahal',
    'status': 'idle',
    'seenAt': nowMs,
    'agents': [
      {
        'id': 'a1',
        'type': 'head',
        'task': '',
        'status': 'done',
        'startedAt': 1,
      },
      {
        'id': 'a2',
        'type': 'coder-low',
        'task': '',
        'status': 'done',
        'startedAt': 2,
      },
      {
        'id': 'a3',
        'type': 'design',
        'task': '',
        'status': 'done',
        'startedAt': 3,
      },
    ],
  });

  @override
  Widget build(BuildContext context) {
    final env = environmentAt(now);
    final nowMs = now.millisecondsSinceEpoch;
    final bg = Color.lerp(
      const Color(0xFF1B1D36),
      const Color(0xFFE9D3AC),
      env.dayness,
    )!;
    return ColoredBox(
      color: bg,
      child: Align(
        alignment: Alignment.topCenter,
        child: OfficeView(
          session: demo(nowMs),
          sprites: sprites,
          env: env,
          serverNow: nowMs,
        ),
      ),
    );
  }
}
