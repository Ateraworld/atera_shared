import "package:quiver/collection.dart";

extension IteableExtensions<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T elem) predicate) {
    var index = indexOf(this, predicate);
    return index < 0 ? null : elementAt(index);
  }
}

extension ListValuesExtensions<T extends num> on List<T> {
  T average() {
    return (reduce((value, element) => (value + element) as T) / length) as T;
  }
}
