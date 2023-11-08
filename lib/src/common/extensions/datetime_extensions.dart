import "package:intl/intl.dart";

extension DateTimeExtensions on DateTime {
  /// Convert the date to a human readable, friendly string in the form dd/mm/yyy
  String toReadableString() {
    return "${day.toString().padLeft(2, "0")}/${month.toString().padLeft(2, "0")}/${year.toString().padLeft(4, "0")} ${hour.toString().padLeft(2, "0")}:${minute.toString().padLeft(2, "0")}";
  }

  /// Convert the date into the format provided
  String format({String format = "dd-MM-yyyy"}) => DateFormat(format).format(this);
}
