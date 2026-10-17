import '../../../core/data/memory_store.dart';
import '../../../core/mock/chain_seed.dart';
import '../../../core/models/branch.dart';

class MockBranchRepository {
  MockBranchRepository({Iterable<Branch>? initialData})
    : _store = MemoryStore<Branch, String>(
        idOf: (item) => item.id,
        initialData: initialData ?? ChainSeed.branches,
        duplicateMessage: 'Branch ID already exists.',
        missingMessage: 'Branch not found.',
      );
  final MemoryStore<Branch, String> _store;
  List<Branch> getAll() => _store.getAll();
  Branch? getById(String id) => _store.getById(id);

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
    _store.add(item);
  }

  void update(Branch item) {
    _validate(item);
    _store.update(item);
  }

  void delete(String id) => _store.delete(id);
}
