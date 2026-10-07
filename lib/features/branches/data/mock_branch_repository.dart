import '../../../core/mock/chain_seed.dart';
import '../../../core/models/branch.dart';

class MockBranchRepository {
  MockBranchRepository({Iterable<Branch>? initialData})
    : _items = List.of(initialData ?? ChainSeed.branches);
  final List<Branch> _items;
  List<Branch> getAll() => List.unmodifiable(_items);
  Branch? getById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  void _validate(Branch item) {
    if ([
      item.id,
      item.name,
      item.address,
      item.phone,
    ].any((s) => s.trim().isEmpty)) {
      throw ArgumentError('Branch fields must not be empty.');
    }
  }

  void add(Branch item) {
    _validate(item);
    if (getById(item.id) != null) throw StateError('Branch ID already exists.');
    _items.add(item);
  }

  void update(Branch item) {
    _validate(item);
    final index = _items.indexWhere((b) => b.id == item.id);
    if (index < 0) throw StateError('Branch not found.');
    _items[index] = item;
  }

  void delete(String id) {
    final index = _items.indexWhere((b) => b.id == id);
    if (index < 0) throw StateError('Branch not found.');
    _items.removeAt(index);
  }
}
