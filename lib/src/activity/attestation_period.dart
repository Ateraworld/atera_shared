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

  static bool hasMatch(String str) => _regExp.hasMatch(str);

  static final RegExp _regExp = RegExp(
    r"^(?<startd>0?[1-9]|[12][0-9]|3[01])-(?<startm>0?[1-9]|1[0-2])\/(?<endd>0?[1-9]|[12][0-9]|3[01])-(?<endm>0?[1-9]|1[0-2])$",
  );

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
