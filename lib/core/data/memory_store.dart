/// Ordered RAM storage shared by mock repositories.
/// Domain validation and permissions belong to the owning feature.
class MemoryStore<T, Id> {
  MemoryStore({
    required this.idOf,
    Iterable<T> initialData = const [],
    this.duplicateMessage = 'ID already exists.',
    this.missingMessage = 'ID not found.',
  }) : _items = List<T>.of(initialData);

  final Id Function(T) idOf;
  final List<T> _items;
  final String duplicateMessage;
  final String missingMessage;

  List<T> getAll() => List<T>.unmodifiable(_items);

  bool any(bool Function(T) test) => _items.any(test);

  T? getById(Id id) {
    final index = _indexOf(id);
    return index < 0 ? null : _items[index];
  }

  void add(T item, {T Function(T)? prepare}) {
    if (_indexOf(idOf(item)) >= 0) throw StateError(duplicateMessage);
    _items.add(prepare == null ? item : prepare(item));
  }

  void update(T item, {T Function(T)? prepare}) {
    final index = _requireIndex(idOf(item));
    _items[index] = prepare == null ? item : prepare(item);
  }

  void delete(Id id) => _items.removeAt(_requireIndex(id));

  int _indexOf(Id id) => _items.indexWhere((item) => idOf(item) == id);

  int _requireIndex(Id id) {
    final index = _indexOf(id);
    if (index < 0) throw StateError(missingMessage);
    return index;
  }
}
