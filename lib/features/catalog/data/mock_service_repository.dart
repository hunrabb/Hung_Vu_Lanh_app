import '../../../core/data/memory_store.dart';
import '../../../core/models/service.dart';

/// In-memory profile/catalog storage. No credentials or authorization here.
class MockServiceRepository {
  MockServiceRepository({Iterable<Service>? initialData}) {
    for (final item in initialData ?? _seed()) {
      add(item);
    }
  }

  final _store = MemoryStore<Service, String>(idOf: (item) => item.id);
  List<Service> getAll() => _store.getAll();
  Service? getById(String id) => _store.getById(id);
  void add(Service item) => _store.add(item, prepare: _prepare);
  void update(Service item) => _store.update(item, prepare: _prepare);
  void delete(String id) => _store.delete(id);

  Service _prepare(Service item) {
    _validate(item);
    return item.copyWith(name: item.name.trim());
  }

  void _validate(Service item) {
    if (item.id.trim().isEmpty || item.name.trim().isEmpty) {
      throw ArgumentError('ID and name must not be empty.');
    }
  }

  static List<Service> _seed() => [
    Service(
      id: 'service-01',
      name: 'Combo Cắt + Gội',
      category: ServiceCategory.haircut,
      durationMinutes: 45,
      priceVnd: 150000,
    ),
    Service(
      id: 'service-02',
      name: 'Gội đầu thư giãn',
      category: ServiceCategory.hairWash,
      durationMinutes: 30,
      priceVnd: 80000,
    ),
    Service(
      id: 'service-03',
      name: 'Uốn tóc tạo kiểu',
      category: ServiceCategory.perm,
      durationMinutes: 90,
      priceVnd: 450000,
    ),
    Service(
      id: 'service-04',
      name: 'Nhuộm màu thời trang',
      category: ServiceCategory.dye,
      durationMinutes: 120,
      priceVnd: 550000,
    ),
    Service(
      id: 'service-05',
      name: 'Massage đầu & vai',
      category: ServiceCategory.massage,
      durationMinutes: 60,
      priceVnd: 200000,
    ),
  ];
}
