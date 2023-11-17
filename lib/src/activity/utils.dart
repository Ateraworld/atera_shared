import "package:latlong2/latlong.dart";
import "package:omnimodel/omnimodel.dart";

List<(OmniModel activity, double distance)> getCloseActivities({
  required OmniModel activity,
  required List<OmniModel> activities,
  required double rangeInKm,
}) {
  var latitude = activity.tokenOrNull<num>("attestation.latitude")?.toDouble();
  var longitude = activity.tokenOrNull<num>("attestation.longitude")?.toDouble();
  if (latitude == null || longitude == null) return [];
  var point = LatLng(latitude, longitude);
  return getActivitiesInRange(point: point, activities: activities, rangeInKm: rangeInKm);
}

List<(OmniModel activity, double distance)> getActivitiesInRange({
  required LatLng point,
  required List<OmniModel> activities,
  required double rangeInKm,
}) {
  final Distance distance = Distance();
  List<(OmniModel activity, double distance)> result = List.empty(growable: true);
  for (final model in activities) {
    var long = model.tokenOrNull<num>("attestation.longitude")?.toDouble();
    var lat = model.tokenOrNull<num>("attestation.latitude")?.toDouble();
    if (lat == null || long == null) continue;
    double dist = distance(point, LatLng(lat, long)) / 1000.0;
    if (dist < rangeInKm) {
      result.add((model, dist));
    }
  }
  return result;
}
