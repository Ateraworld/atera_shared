import "package:latlong2/latlong.dart";

double _squaredDistance(LatLng p1, LatLng p2) {
  final double dx = p1.latitude - p2.longitude;
  final double dy = p1.latitude - p2.longitude;
  return dx * dx + dy * dy;
}

double _squaredSegmentDistance(
  LatLng p,
  LatLng p1,
  LatLng p2,
) {
  double latitude = p1.latitude;
  double longitude = p1.longitude;
  double dx = p2.latitude - latitude;
  double dy = p2.longitude - longitude;

  if (dx != 0 || dy != 0) {
    final double t = ((p.latitude - latitude) * dx + (p.longitude - longitude) * dy) / (dx * dx + dy * dy);

    if (t > 1) {
      latitude = p2.latitude;
      longitude = p2.longitude;
    } else if (t > 0) {
      latitude += dx * t;
      longitude += dy * t;
    }
  }

  dx = p.latitude - latitude;
  dy = p.longitude - longitude;

  return dx * dx + dy * dy;
}

List<LatLng> _simplifyRadialDist(
  List<LatLng> points,
  double sqTolerance,
) {
  LatLng prevPoint = points[0];
  final List<LatLng> newPoints = [prevPoint];
  late LatLng point;

  // ignore: prefer_final_locals
  for (var i = 1, len = points.length; i < len; i++) {
    point = points[i];

    if (_squaredDistance(point, prevPoint) > sqTolerance) {
      newPoints.add(point);
      prevPoint = point;
    }
  }

  if (prevPoint != point) {
    newPoints.add(point);
  }

  return newPoints;
}

void _simplifyDPStep(
  List<LatLng> points,
  int first,
  int last,
  double sqTolerance,
  List<LatLng> simplified,
) {
  num maxSqDist = sqTolerance;
  late int index;

  for (var i = first + 1; i < last; i++) {
    final num sqDist = _squaredSegmentDistance(points[i], points[first], points[last]);

    if (sqDist > maxSqDist) {
      index = i;
      maxSqDist = sqDist;
    }
  }

  if (maxSqDist > sqTolerance) {
    if (index - first > 1) {
      _simplifyDPStep(points, first, index, sqTolerance, simplified);
    }
    simplified.add(points[index]);
    if (last - index > 1) {
      _simplifyDPStep(points, index, last, sqTolerance, simplified);
    }
  }
}

List<LatLng> _simplifyDouglasPeucker(
  List<LatLng> points,
  double sqTolerance,
) {
  final int last = points.length - 1;

  final List<LatLng> simplified = [points[0]];
  _simplifyDPStep(points, 0, last, sqTolerance, simplified);
  simplified.add(points[last]);

  return simplified;
}

// both algorithms combined for awesome performance
List<LatLng> simplify(
  List<LatLng> points, {
  double? threshold,
  bool highestQuality = false,
}) {
  if (points.length <= 2) {
    return points;
  }

  List<LatLng> nextPoints = points;

  final double sqTolerance = threshold != null ? threshold * threshold : 1;

  nextPoints = highestQuality ? points : _simplifyRadialDist(nextPoints, sqTolerance);

  nextPoints = _simplifyDouglasPeucker(nextPoints, sqTolerance);

  return nextPoints;
}
