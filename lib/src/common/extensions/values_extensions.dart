extension ValuesExtensions<T extends num> on T {
  T roundSeed(T seed) {
    var diff = this % seed;
    return diff >= seed / 2 ? (this - diff + seed).floor() as T : (this - diff).floor() as T;
  }

  T remap((T, T) bounds) {
    var val = clamp(bounds.$1, bounds.$2);
    return (val - bounds.$1) / (bounds.$2 - bounds.$1) as T;
  }
}
