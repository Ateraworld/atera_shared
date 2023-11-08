extension ListExtensions<T> on List<T> {
  T? firstWhereOrNull(bool Function(T elem) predicate) {
    var index = indexWhere(predicate);
    return index < 0 ? null : this[index];
  }
}

extension ListValuesExtensions<T extends num> on List<T> {
  T average() {
    return (reduce((value, element) => (value + element) as T) / length) as T;
  }
}
