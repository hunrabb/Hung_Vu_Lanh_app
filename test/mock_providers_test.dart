import 'support/test_access.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/models/app_user.dart';
import 'package:ktgk/core/models/service.dart';
import 'package:ktgk/features/catalog/data/mock_service_repository.dart';
import 'package:ktgk/features/catalog/application/service_provider.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';
import 'package:ktgk/features/users/application/user_provider.dart';
import 'package:ktgk/features/manager/presentation/manager_service_screen.dart';

void main() {
  test('Service CRUD notifies only after success and protects snapshots', () {
    final repository = MockServiceRepository(initialData: []);
    final provider = ServiceProvider(repository, access: testAccess());
    addTearDown(provider.dispose);
    var notifications = 0;
    provider.addListener(() => notifications++);
    final service = Service(
      id: 's',
      name: 'Test',
      category: ServiceCategory.haircut,
      durationMinutes: 30,
      priceVnd: 100000,
    );
    provider.add(service);
    final snapshot = provider.services;
    expect(() => snapshot.clear(), throwsUnsupportedError);
    expect(() => provider.add(service), throwsStateError);
    expect(notifications, 1);
    provider.update(service.copyWith(priceVnd: 120000));
    expect(provider.getById('s')!.priceVnd, 120000);
    expect(snapshot.single.priceVnd, 100000);
    provider.delete('s');
    expect(provider.services, isEmpty);
    expect(notifications, 3);
    expect(() => provider.update(service), throwsStateError);
    expect(() => provider.delete('s'), throwsStateError);
    expect(MockServiceRepository().getAll(), hasLength(5));
  });

  test('User CRUD normalizes emails and rejects conflicting updates', () {
    final provider = UserProvider(
      MockUserRepository(initialData: []),
      access: testAccess(),
    );
    addTearDown(provider.dispose);
    var notifications = 0;
    provider.addListener(() => notifications++);
    final user = AppUser(
      id: 'u',
      name: 'User',
      email: ' TEST@EXAMPLE.COM ',
      role: UserRole.customer,
      createdAt: DateTime.utc(2026),
    );
    provider.add(user);
    expect(provider.getById('u')!.email, 'test@example.com');
    expect(() => provider.add(user.copyWith(id: 'other')), throwsStateError);
    provider.add(user.copyWith(id: 'other', email: 'other@example.com'));
    expect(
      () => provider.update(user.copyWith(email: 'other@example.com')),
      throwsStateError,
    );
    expect(provider.getById('u')!.email, 'test@example.com');
    provider.update(user.copyWith(name: 'Updated'));
    expect(provider.getById('u')!.name, 'Updated');
    expect(() => provider.users.clear(), throwsUnsupportedError);
    provider.delete('u');
    expect(provider.getById('u'), isNull);
    expect(notifications, 4);
    expect(() => provider.delete('u'), throwsStateError);
  });

  testWidgets('Admin service list and count react to provider changes', (
    tester,
  ) async {
    final provider = ServiceProvider(
      MockServiceRepository(initialData: []),
      access: testAccess(),
    );
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: provider,
        child: const MaterialApp(home: ManagerServiceScreen()),
      ),
    );
    expect(find.text('0 dịch vụ · Chăm sóc & tạo kiểu'), findsOneWidget);
    final service = Service(
      id: 'new',
      name: 'New service',
      category: ServiceCategory.shaving,
      durationMinutes: 20,
      priceVnd: 1234567,
    );
    provider.add(service);
    await tester.pump();
    expect(find.text('New service'), findsOneWidget);
    expect(find.text('1.234.567đ'), findsOneWidget);
    expect(find.text('20 phút'), findsOneWidget);
    provider.update(service.copyWith(name: 'Updated service'));
    await tester.pump();
    expect(find.text('Updated service'), findsOneWidget);
    provider.delete('new');
    await tester.pump();
    expect(find.text('Updated service'), findsNothing);
    expect(find.text('0 dịch vụ · Chăm sóc & tạo kiểu'), findsOneWidget);
  });
}
