import 'package:flutter/foundation.dart';

import '../../../core/data/memory_store.dart';

import '../../../core/models/app_user.dart';

/// In-memory profile/catalog storage. No credentials or authorization here.
class MockUserRepository extends ChangeNotifier {
  MockUserRepository({Iterable<AppUser>? initialData}) {
    for (final item in initialData ?? _seed()) {
      add(item);
    }
  }

  final _store = MemoryStore<AppUser, String>(idOf: (item) => item.id);
  List<AppUser> getAll() => _store.getAll();
  AppUser? getById(String id) => _store.getById(id);

  void add(AppUser item) {
    _store.add(item, prepare: _prepare);
    notifyListeners();
  }

  void update(AppUser item) {
    _store.update(item, prepare: _prepare);
    notifyListeners();
  }

  void delete(String id) {
    _store.delete(id);
    notifyListeners();
  }

  AppUser _prepare(AppUser item) {
    _validate(item);
    return item.copyWith(
      name: item.name.trim(),
      email: item.email.trim().toLowerCase(),
    );
  }

  void _validate(AppUser item) {
    if (item.id.trim().isEmpty || item.name.trim().isEmpty) {
      throw ArgumentError('ID and name must not be empty.');
    }
    final email = item.email.trim().toLowerCase();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      throw ArgumentError('Invalid email.');
    }
    if (_store.any((other) => other.id != item.id && other.email == email)) {
      throw StateError('Email already exists.');
    }
  }

  static List<AppUser> _seed() => [
    AppUser(
      id: 'boss-01',
      name: 'Boss Demo',
      email: 'boss@example.com',
      role: UserRole.superAdmin,
      isApproved: true,
      createdAt: DateTime.utc(2026),
    ),
    AppUser(
      id: 'manager-02',
      name: 'Manager 2',
      email: 'manager2@example.com',
      role: UserRole.manager,
      branchId: 'branch-02',
      isApproved: true,
      createdAt: DateTime.utc(2026),
    ),
    AppUser(
      id: 'staff-06',
      name: 'Pending Staff',
      email: 'pending@example.com',
      role: UserRole.staff,
      branchId: 'branch-01',
      isApproved: false,
      specializedCategoryIds: ['haircut'],
      createdAt: DateTime.utc(2026),
    ),

    AppUser(
      id: 'customer-01',
      name: 'Customer Demo',
      email: 'customer@example.com',
      role: UserRole.customer,
      createdAt: DateTime.utc(2026, 1, 1),
      loyaltyPoints: 150,
    ),
    AppUser(
      id: 'admin-01',
      name: 'Manager Demo',
      email: 'admin@example.com',
      role: UserRole.manager,
      branchId: 'branch-01',
      isApproved: true,
      createdAt: DateTime.utc(2026, 1, 1),
    ),
    AppUser(
      id: 'staff-01',
      name: 'Nguyễn Minh Hùng',
      email: 'staff@exampler.com',
      role: UserRole.staff,
      branchId: 'branch-01',
      isApproved: true,
      createdAt: DateTime.utc(2026, 1, 1),
      specializedCategoryIds: ['haircut', 'hairWash'],
      averageRating: 4.9,
      isFeatured: true,
    ),
    AppUser(
      id: 'staff-02',
      name: 'Trần Ngọc Linh',
      email: 'linh@example.com',
      role: UserRole.staff,
      branchId: 'branch-02',
      isApproved: false,
      createdAt: DateTime.utc(2026, 1, 1),
      specializedCategoryIds: ['dye'],
      averageRating: 4.9,
      isFeatured: true,
    ),
    AppUser(
      id: 'staff-03',
      name: 'Alex Nguyễn',
      email: 'alex@example.com',
      role: UserRole.staff,
      branchId: 'branch-01',
      isApproved: true,
      createdAt: DateTime.utc(2026, 1, 1),
      specializedCategoryIds: ['haircut', 'perm'],
      averageRating: 4.9,
      isFeatured: true,
    ),
    AppUser(
      id: 'staff-04',
      name: 'Lê Thanh Minh',
      email: 'minh@example.com',
      role: UserRole.staff,
      branchId: 'branch-02',
      isApproved: false,
      createdAt: DateTime.utc(2026, 1, 1),
      specializedCategoryIds: ['massage'],
      averageRating: 4.9,
      isFeatured: true,
    ),
    AppUser(
      id: 'staff-05',
      name: 'Phạm Gia An',
      email: 'an@example.com',
      role: UserRole.staff,
      branchId: 'branch-02',
      isApproved: true,
      createdAt: DateTime.utc(2026, 1, 1),
      specializedCategoryIds: ['hairWash'],
      averageRating: 4.9,
      isFeatured: true,
    ),
  ];
}
