import "package:latlong2/latlong.dart";
import "package:omnimodel/omnimodel.dart";

/// Handles the attestation period string and parsing
class AttestationPeriod {
  AttestationPeriod._(this.startDay, this.startMonth, this.endDay, this.endMonth);

  static const _monthsMap = [
    "Gennaio",
    "Febbraio",
    "Marzo",
    "Aprile",
    "Maggio",
    "Giugno",
    "Luglio",
    "Agosto",
    "Settembre",
    "Ottobre",
    "Novembre",
    "Dicembre",
  ];
  static final RegExp _regExp = RegExp(
    r"^(?<startd>0?[1-9]|[12][0-9]|3[01])\-(?<startm>0?[1-9]|1[0-2])\/(?<endd>0?[1-9]|[12][0-9]|3[01])\-(?<endm>0?[1-9]|1[0-2])$",
  );

  String getActivityFolderName(String activityName) => removeDiacritics(activityName.toLowerCase().trim().replaceAll(RegExp("[ ]{1,}"), "_"));

  String removeDiacritics(String str) {
    var withDia = "ÀÁÂÃÄÅàáâãäåÒÓÔÕÕÖØòóôõöøÈÉÊËèéêëðÇçÐÌÍÎÏìíîïÙÚÛÜùúûüÑñŠšŸÿýŽž";
    var withoutDia = "AAAAAAaaaaaaOOOOOOOooooooEEEEeeeeeCcDIIIIiiiiUUUUuuuuNnSsYyyZz";

    for (int i = 0; i < withDia.length; i++) {
      str = str.replaceAll(withDia[i], withoutDia[i]);
    }

    return str;
  }

  final int startDay;
  final int startMonth;
  final int endDay;
  final int endMonth;
  String format({separator = " - "}) => "$startDay ${_monthsMap[startMonth - 1]}$separator$endDay ${_monthsMap[endMonth - 1]}";

  bool isDateValid(DateTime dateTime) {
    if (startMonth <= endMonth) {
      if ((startMonth == dateTime.month && dateTime.day < startDay) || (endMonth == dateTime.month && dateTime.month > endDay)) {
        return false;
      }
      if (dateTime.month < startMonth || dateTime.month > endMonth) {
        return false;
      }
    } else {
      if ((startMonth == dateTime.month && dateTime.day < startDay) || (endMonth == dateTime.month && dateTime.day > endDay)) {
        return false;
      }
      if (dateTime.month < startMonth && dateTime.month > endMonth) {
        return false;
      }
    }
    return true;
  }

  static AttestationPeriod? tryParse(String pattern) {
    var match = _regExp.firstMatch(pattern);
    if (match == null) return null;
    try {
      var startd = int.tryParse(match.namedGroup("startd")!);
      var startm = int.tryParse(match.namedGroup("startm")!);
      var endd = int.tryParse(match.namedGroup("endd")!);
      var endm = int.tryParse(match.namedGroup("endm")!);
      var period = AttestationPeriod._(startd!, startm!, endd!, endm!);
      return period;
    } catch (error) {
      return null;
    }
  }
}

List<(OmniModel activity, double distance)> getCloseActivities({
  required OmniModel activity,
  required List<OmniModel> activities,
  required double rangeInKm,
}) {
  var latitude = activity.tokenOrNull<num>("attestation.latitude")?.toDouble();
  var longitude = activity.tokenOrNull<num>("attestation.longitude")?.toDouble();
  if (latitude == null || longitude == null) return [];
  var point = LatLng(latitude, longitude);
  var id = activity.tokenOr("id", "");
  activities.removeWhere((element) => element.tokenOr("id", "") == id);
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
