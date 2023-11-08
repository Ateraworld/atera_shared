import "dart:io";

extension DirectoryExtensions on Directory {
  /// Returns the size in KB of the wholde folder, included nested files
  Future<int> sizeKb() async {
    var files = await list(recursive: true).toList();
    var dirSize = files.fold(0, (int sum, file) => sum + file.statSync().size);
    return dirSize;
  }

  /// Get the first parent that satisfies the predicate
  Future<Directory?> predicateMatchingParent(Future<bool> Function(FileSystemEntity file) predicate) async {
    Directory current = this;
    do {
      var elems = current.listSync(recursive: false);
      for (final e in elems) {
        if (await predicate.call(e)) return current;
      }
      current = current.parent;
    } while (current.path != current.parent.path);
    return null;
  }
}
