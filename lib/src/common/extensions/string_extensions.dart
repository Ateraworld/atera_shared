import "dart:math";

import "package:intl/intl.dart";
import "package:quiver/iterables.dart" as iterables;

extension StringExtensions on String {
  /// Converter to allow fast conversion of string values.
  ///
  /// I.E:
  ///
  /// `float v = "1.5".convert(float.parse);`
  T convert<T>(T Function(String) converter) => converter(this);

  /// Capitalize a string.If [forceLowerCaseBody] is true, all the body is enforced to lower case
  String capitalized({bool forceLowerCaseBody = false}) {
    if (isEmpty) return this;
    var suffix = forceLowerCaseBody ? substring(1).toLowerCase() : substring(1);
    return "${this[0].toUpperCase()}$suffix";
  }

  /// Attempt to convert a country code to its corresponding flag. Returns empty string on error
  String toFlagEmoji() {
    try {
      if (isEmpty || length < 2) return "";
      var str = toUpperCase();
      final int firstLetter = str.codeUnitAt(0) - 0x41 + 0x1F1E6;
      final int secondLetter = str.codeUnitAt(1) - 0x41 + 0x1F1E6;
      return String.fromCharCode(firstLetter) + String.fromCharCode(secondLetter);
    } catch (error) {
      return "";
    }
  }

  /// Returns a value between `0` and `1` indicating the similarity ratio of the two substrings
  ///
  /// Uses the algorithm of similarity convolution: the smallest substring is convoluted on the other one and the maximum number of equal tokens is calculated for each convolution step.
  /// In the end the ratio between the largest convoluted characters match and the length of the minimum sequence is returned
  double similarityConvolution(String t, {bool caseSensitive = false}) {
    var minSeq = length < t.length
        ? caseSensitive
            ? this
            : toLowerCase()
        : caseSensitive
            ? t
            : t.toLowerCase();
    var maxSeq = length < t.length
        ? caseSensitive
            ? t
            : t.toLowerCase()
        : caseSensitive
            ? this
            : toLowerCase();

    var maxMatch = 0;

    // Convolution
    for (var i = 0; i < maxSeq.length; i++) {
      var cost = 0;
      if (i + minSeq.length > maxSeq.length) return maxMatch / minSeq.length;
      for (var j = 0; j < minSeq.length; j++) {
        cost += maxSeq[i + j] == minSeq[j] ? 1 : 0;
      }
      maxMatch = max(maxMatch, cost);
    }
    return maxMatch / minSeq.length;
  }

  /// Try to parse a date from the string with the specified format
  DateTime? toDate({String format = "dd-MM-yyy"}) {
    try {
      return DateFormat(format).parse(this);
    } catch (_) {
      return null;
    }
  }

  /// Format the date into a certain form
  String toDateFormat({String format = "dd-MM-yyy"}) {
    var date = DateTime.tryParse(this);
    if (date == null) return this;
    return DateFormat(format).format(date);
  }

  /// Capitalize the string based on its words and a separator.
  ///
  /// If [trimTokens] is true, each split is first trimmed, to remove trailing whitespaces.
  ///
  /// Separators are decided in the following order, depending whether they are found in the string:
  /// * `_`: if at least one char is found, split based on this token
  /// * ` `: split using the space
  String toWordCapitalized({bool trimTokens = true}) {
    if (isEmpty) return this;
    var separator = " ";
    if (contains("_")) {
      separator = "_";
    }
    var res = trimTokens ? trim() : this;
    var tokens = res.split(separator);
    var buf = StringBuffer();
    for (int i = 0; i < tokens.length; i++) {
      var element = tokens[i];
      if (trimTokens && element.replaceAll(separator, "").isEmpty) continue;
      buf.write(element.capitalized());
      if (i < tokens.length - 1) {
        buf.write(" ");
      }
    }
    return buf.toString();
  }

  // Replace all unicode elements with the corresponding char codec
  String unicodeSanitize() {
    return replaceAllMapped(
      RegExp(r"\\u([0-9a-fA-F]{4})"),
      (Match m) => String.fromCharCode(int.parse(m.group(1)!, radix: 16)),
    );
  }

  /// Given two semantic versions in the form **vv.pp.bb**, compare whether the first one is greater
  bool isSemanticVersionGreater(String second) {
    try {
      var fSplits = split(".").map(int.parse);
      var sSplits = second.split(".").map(int.parse);
      for (final e in iterables.zip([fSplits, sSplits])) {
        if (e[0] > e[1]) {
          return true;
        } else if (e[0] < e[1]) {
          return false;
        }
      }
      return fSplits.length > sSplits.length;
    } catch (_) {
      return false;
    }
  }
}
