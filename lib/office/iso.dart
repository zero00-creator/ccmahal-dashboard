import 'dart:ui';

/// Maps grid coordinates of the isometric room to screen points.
///
/// `gx` runs down and to the right, `gy` down and to the left, `z` is height.
class IsoProjection {
  const IsoProjection({
    required this.tileW,
    required this.tileH,
    required this.origin,
  });

  final double tileW;
  final double tileH;
  final Offset origin;

  Offset toScreen(double gx, double gy, [double z = 0]) => Offset(
    origin.dx + (gx - gy) * tileW / 2,
    origin.dy + (gx + gy) * tileH / 2 - z,
  );
}
