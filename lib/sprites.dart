import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart' show rootBundle;

/// One pixel rectangle of a crab skin, on the skin's 30x28 grid. `cls` is `bd`
/// for the body and its costume, `la` / `lb` for the two leg pairs, anything
/// else for a prop that moves on its own.
class Px {
  const Px(this.x, this.y, this.w, this.h, this.color, this.cls);
  final int x, y, w, h;
  final Color color;
  final String cls;
}

class Skin {
  const Skin(this.name, this.accent, this.pixels);
  final String name;
  final Color accent;
  final List<Px> pixels;
}

const skinWidth = 30;
const skinHeight = 28;

Color parseHex(String value) {
  // Skins use `#RRGGBB` and, once, a CSS `rgba(r,g,b,a)` for the magnifier glass.
  if (value.startsWith('rgba')) {
    final parts = value
        .substring(value.indexOf('(') + 1, value.indexOf(')'))
        .split(',')
        .map((s) => double.tryParse(s.trim()) ?? 0)
        .toList();
    if (parts.length == 4) {
      return Color.fromARGB(
        (parts[3] * 255).round().clamp(0, 255),
        parts[0].round(),
        parts[1].round(),
        parts[2].round(),
      );
    }
  }
  var h = value.replaceFirst('#', '');
  if (h.length == 3) h = h.split('').map((c) => '$c$c').join();
  final v = int.tryParse(h.length == 6 ? 'FF$h' : h, radix: 16) ?? 0xFFFF00FF;
  return Color(v);
}

/// The pixel skins of my-mod, exported from its `skins/*.ts` files into
/// `assets/sprites.json`.
class SpriteSet {
  SpriteSet(this._skins);
  final Map<String, Skin> _skins;

  static Future<SpriteSet> load() async =>
      SpriteSet.fromJson(await rootBundle.loadString('assets/sprites.json'));

  factory SpriteSet.fromJson(String source) {
    final data = jsonDecode(source) as Map<String, dynamic>;
    final skins = <String, Skin>{};
    data.forEach((name, v) {
      final m = v as Map<String, dynamic>;
      final px = <Px>[
        for (final r in (m['rects'] as List))
          Px(
            (r[0] as num).toInt(),
            (r[1] as num).toInt(),
            (r[2] as num).toInt(),
            (r[3] as num).toInt(),
            parseHex(r[4] as String),
            r[5] as String,
          ),
      ];
      skins[name] = Skin(name, parseHex(m['color'] as String), px);
    });
    return SpriteSet(skins);
  }

  /// The skin of an agent type (`coder-low`, or `plugin:coder-low`); any
  /// type without a skin gets the plain crab.
  Skin forType(String type) {
    final t = type.contains(':') ? type.split(':').last : type;
    return _skins[t] ?? _skins['other']!;
  }

  Skin get main => _skins['main'] ?? _skins['other']!;
}
