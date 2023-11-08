import "dart:math";

import "package:vector_math/vector_math.dart";

extension Vector2Extensions on Vector2 {
  int randomRange(Random random) => (y - x) <= 0 ? x.toInt() : x.round() + random.nextInt((y - x).round());

  Duration msRandomDuration(Random random) => Duration(milliseconds: x.round() + random.nextInt((y - x).round()));
}
