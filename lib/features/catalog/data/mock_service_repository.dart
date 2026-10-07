import '../../../core/models/service.dart';

/// In-memory profile/catalog storage. No credentials or authorization here.
class MockServiceRepository {
  MockServiceRepository({Iterable<Service>? initialData}) {
    for (final item in initialData ?? _seed()) {
      add(item);
    }
  }

  final List<Service> _items = [];
  List<Service> getAll() => List.unmodifiable(_items);
  Service? getById(String id) {
    for (final item in _items) {
      if (item.id == id) return item;
    }
    return null;
  }

  void add(Service item) {
    if (getById(item.id) != null) throw StateError('ID already exists.');
    _validate(item);
    _items.add(item.copyWith(name: item.name.trim()));
  }

  void update(Service item) {
    final index = _items.indexWhere((other) => other.id == item.id);
    if (index < 0) throw StateError('ID not found.');
    _validate(item);
    _items[index] = item.copyWith(name: item.name.trim());
  }

  void delete(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index < 0) throw StateError('ID not found.');
    _items.removeAt(index);
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
