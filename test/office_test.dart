import 'dart:io';

import 'package:ccmahal_dashboard/sprites.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the exported skins load and every agent type has a sprite', () {
    final set = SpriteSet.fromJson(
      File('assets/sprites.json').readAsStringSync(),
    );
    for (final t in [
      'head',
      'planning',
      'manager',
      'coder-high',
      'coder-low',
      'debugger',
      'ask-anything',
      'design',
    ]) {
      expect(set.forType(t).pixels, isNotEmpty, reason: t);
      expect(set.forType(t).name, t);
    }
    expect(set.forType('plugin:coder-low').name, 'coder-low');
    expect(set.forType('something-else').name, 'other');
    expect(set.main.name, 'main');
  });

  test('skin colours in #rgb and rgba() form are read, not turned magenta', () {
    expect(parseHex('#fff'), const Color(0xFFFFFFFF));
    expect(parseHex('#2FA66B'), const Color(0xFF2FA66B));
    final glass = parseHex('rgba(169,214,245,.7)');
    expect(glass.a, closeTo(0.7, 0.01));
    expect((glass.r * 255).round(), 169);
    for (final skin in ['debugger', 'coder-low', 'main']) {
      final set = SpriteSet.fromJson(
        File('assets/sprites.json').readAsStringSync(),
      );
      expect(
        set.forType(skin).pixels.any((p) => p.color == const Color(0xFFFF00FF)),
        isFalse,
        reason: '$skin has an unreadable colour',
      );
    }
  });
}
