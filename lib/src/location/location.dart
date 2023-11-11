import "dart:math" as math;

import "package:omnimodel/omnimodel.dart";
import "package:point_in_polygon/point_in_polygon.dart";

/// Get all the countries in the location model in the form `(code, model)`
List<(String, OmniModel)> getLocationCountries(OmniModel locationModel) => locationModel.entries.map((e) => (e.key, OmniModel.fromDynamic(e.value))).toList();

/// Get all the regions given a set of countries in the location model in the form `(code, model)`
List<(String, OmniModel)> getLocationRegions(OmniModel locationModel, List<String> countries) {
  final List<(String, OmniModel)> res = List.empty(growable: true);
  for (final country in locationModel.entries.where((element) => countries.contains(element.key))) {
    res.addAll(OmniModel.fromDynamic(country.value).tokenAsModel("regions").entries.map((e) => (e.key, OmniModel.fromDynamic(e.value))));
  }
  return res;
}

/// Using the three geojson data, attempt to locate a point and return a model in the form:
/// ```
/// {
///   "zone": String,
///   "region": String,
///   "province": String
/// }
/// ```
///
/// At the moment is limited in Italy (IT) only.
Future<OmniModel> locatePoint({
  required math.Point<double> p,
  required OmniModel provincesGeoJson,
  required OmniModel regionsGeoJson,
  required OmniModel zonesGeoJson,
}) async {
  OmniModel location = OmniModel.empty();

  var points = List<Point>.empty(growable: true);
  location.edit({"zone": _getLocationFromModel(zonesGeoJson, p, points)});
  location.edit({"province": _getLocationFromModel(provincesGeoJson, p, points)});
  location.edit({"region": _getLocationFromModel(regionsGeoJson, p, points)});
  return location;
}

String? _getLocationFromModel(OmniModel model, math.Point<double> p, List<Point> points) {
  for (final zone in model.tokenOr("features", [])) {
    points.clear();
    var model = OmniModel.fromDynamic(zone);
    var coords = model.tokenOr("geometry.coordinates", []);
    for (final coordArr in coords) {
      points.addAll(List.generate(coordArr.length, (index) => Point(x: coordArr[index][0], y: coordArr[index][1])));
    }
    if (Poly.isPointInPolygon(Point(x: p.x, y: p.y), points)) {
      return model.tokenOrNull("properties.name");
    }
  }

  return null;
}

/// Get all the provinces given a set of countries and regions in the location model in the form `(code, model)`
List<(String, OmniModel)> getLocationProvinces(OmniModel locationModel, List<String> countries, List<String> regions) {
  final List<(String, OmniModel)> res = List.empty(growable: true);
  var filtered = getLocationRegions(locationModel, countries).where((element) => regions.contains(element.$1));

  for (final region in filtered) {
    res.addAll(region.$2.entries.map((e) => (e.key, OmniModel.fromDynamic(e.value))));
  }
  return res;
}

/// Get all the zones given a set of countries in the location model in the form `(code, model)`
List<(String, OmniModel)> getLocationZones(OmniModel locationModel, List<String> countries) {
  final List<(String, OmniModel)> res = List.empty(growable: true);
  for (final country in locationModel.entries.where((element) => countries.contains(element.key))) {
    res.addAll(OmniModel.fromDynamic(country.value).tokenAsModel("zones").entries.map((e) => (e.key, OmniModel.fromDynamic(e.value))));
  }
  return res;
}
