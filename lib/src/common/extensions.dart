import "dart:io";

extension StringExtensions on String {
  T convert<T>(T Function(String) converter) => converter(this);

  String capitalized({bool forceLowerCaseBody = false}) {
    if (isEmpty) return this;
    var suffix = forceLowerCaseBody ? substring(1).toLowerCase() : substring(1);
    return "${this[0].toUpperCase()}$suffix";
  }

  /// Capitalize the string based on its words and a separator
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
}

extension DirectoryExtensions on Directory {
  Future<int> size() async {
    var files = await list(recursive: true).toList();
    var dirSize = files.fold(0, (int sum, file) => sum + file.statSync().size);
    return dirSize;
  }
}

extension ListExtensions<T> on List<T> {
  T? firstWhereOrNull(bool Function(T elem) predicate) {
    var index = indexWhere(predicate);
    return index < 0 ? null : this[index];
  }
}
