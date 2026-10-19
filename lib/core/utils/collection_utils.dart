/// Returns the first matching item, or null if no item matches.
/// T is inferred from items and is preserved in the return type.
T? findFirst<T>(Iterable<T> items, bool Function(T item) matches) {
  for (final item in items) {
    if (matches(item)) return item;
  }
  return null;
}
