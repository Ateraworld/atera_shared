extension ListExtensions<T> on List<T> {
  T? firstWhereOrNull(bool Function(T elem) predicate) {
    var index = indexWhere(predicate);
    return index < 0 ? null : this[index];
  }
}
