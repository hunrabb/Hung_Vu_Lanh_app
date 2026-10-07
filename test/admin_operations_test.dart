import 'support/booking_test_scope.dart';
import 'support/test_access.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/app.dart';
import 'package:ktgk/core/models/app_user.dart';
import 'package:ktgk/core/models/appointment.dart';
import 'package:ktgk/core/models/shop_settings.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';
import 'package:ktgk/features/users/application/user_provider.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';
import 'package:ktgk/features/catalog/application/service_provider.dart';
import 'package:ktgk/features/catalog/data/mock_service_repository.dart';
import 'package:ktgk/features/booking/application/appointment_provider.dart';
import 'package:ktgk/features/booking/data/mock_appointment_repository.dart';
import 'package:ktgk/features/manager/presentation/manager_main.dart';

void main() {
  testWidgets('Manager creates a pending profile without issuing credentials', (
    tester,
  ) async {
    await tester.pumpWidget(const BarbershopApp(useMock: true));
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'admin@example.com');
    await tester.enterText(fields.at(1), 'admin123');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Login'));
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pumpAndSettle();
    final profiles = tester
        .element(find.byType(ManagerMain))
        .read<UserProvider>();
    final before = profiles.users.length;
    final auth = tester
        .element(find.byType(ManagerMain))
        .read<AuthController>();
    await tester.tap(find.text('Thêm nhân viên'));
    await tester.pumpAndSettle();
    for (final entry in [
      'New Staff',
      'forbidden@example.com',
      '0901234567',
      'Cầu Giấy, Hà Nội',
    ].asMap().entries) {
      await tester.enterText(
        find.byType(TextFormField).at(entry.key),
        entry.value,
      );
    }
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(FilterChip).first);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(FilterChip).first);
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(profiles.users.length, before + 1);
    expect(find.byType(AlertDialog), findsNothing);
    final staff = profiles.users.singleWhere(
      (u) => u.email == 'forbidden@example.com',
    );
    expect(staff.branchId, auth.currentUser!.branchId);
    expect(staff.isApproved, isFalse);
    expect(staff.phone, '0901234567');
    expect(staff.address, 'Cầu Giấy, Hà Nội');
    auth.signOut();
    final login = await tester.runAsync(
      () => auth.signIn(email: staff.email, password: 'pass'),
    );
    expect(login, isFalse);
    await tester.pumpAndSettle();
  });
  test('Staff credentials share profiles, edit preserves password and delete revokes login', () {
    final repo = MockUserRepository();
    final auth = MockAuthRepository(users: repo);
    final provider = UserProvider(repo, auth: auth, access: testAccess());
    addTearDown(provider.dispose);
    final admin = auth.signIn(email: 'boss@example.com', password: 'boss123')!;
    final user = AppUser(
      id: 'new-staff',
      name: 'New',
      email: 'new@example.com',
      role: UserRole.staff,
      branchId: 'branch-01',
      isApproved: true,
      createdAt: DateTime.now(),
    );
    expect(
      () => provider.createStaff(user, 'pass', actor: user),
      throwsStateError,
    );
    provider.createStaff(user, 'pass', actor: admin);
    expect(auth.signIn(email: user.email, password: 'pass')?.id, user.id);
    expect(
      () => provider.createStaff(
        user.copyWith(id: 'duplicate'),
        'pass',
        actor: admin,
      ),
      throwsStateError,
    );
    provider.update(user.copyWith(email: 'edited@example.com'));
    expect(auth.signIn(email: 'new@example.com', password: 'pass'), isNull);
    expect(
      auth.signIn(email: 'edited@example.com', password: 'pass')?.id,
      user.id,
    );
    provider.delete(user.id);
    expect(auth.signIn(email: 'edited@example.com', password: 'pass'), isNull);
  });

  testWidgets(
    'Admin shortcuts create staff credentials and book walk-in using shared availability',
    (tester) async {
      final repo = MockUserRepository();
      final authRepo = MockAuthRepository(users: repo);
      final auth = AuthController(authRepo);
      final users = UserProvider(repo, auth: authRepo, access: testAccess());
      final services = ServiceProvider(
        MockServiceRepository(),
        access: testAccess(),
      );
      final booking = AppointmentProvider(
        MockAppointmentRepository(initialData: []),
        services: services,
        users: users,
        settings: ShopSettings(
          branchId: 'branch-01',
          openingMinute: 480,
          closingMinute: 600,
        ),
        clock: () => DateTime.utc(2030, 1, 1),
        access: testAccess(),
      );
      addTearDown(auth.dispose);
      addTearDown(users.dispose);
      addTearDown(services.dispose);
      addTearDown(booking.dispose);
      await tester.runAsync(
        () => auth.signIn(email: 'admin@example.com', password: 'admin123'),
      );
      await tester.pumpWidget(
        BookingTestScope(
          manager: true,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              ChangeNotifierProvider.value(value: users),
              ChangeNotifierProvider.value(value: services),
              ChangeNotifierProvider.value(value: booking),
            ],
            child: const MaterialApp(home: ManagerMain()),
          ),
        ),
      );
      await tester.tap(find.text('Thêm nhân viên'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.dashboard_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Quản lý'));
      await tester.pumpAndSettle();
      expect(find.text('Quản lý Dịch vụ'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.dashboard_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tạo lịch nhanh'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextField).first,
        'Khách vãng lai / 0901234567',
      );
      final dropdowns = find.byType(DropdownButtonFormField<String>);
      await tester.tap(dropdowns.at(1));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Combo Cắt + Gội · 45 phút').last);
      await tester.pumpAndSettle();
      await tester.tap(dropdowns.last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nguyễn Minh Hùng').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(ChoiceChip).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ChoiceChip).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Xác nhận'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
      await tester.pumpAndSettle();
      final item = booking.appointments.single;
      expect(item.customerId, 'walk-in');
      expect(item.customerName, 'Khách vãng lai / 0901234567');
      expect(
        Appointment.fromJson(item.toJson()).customerName,
        item.customerName,
      );
      expect(
        () => booking.book(
          customerId: 'customer-01',
          staffId: item.staffId,
          serviceId: 'service-01',
          startAt: item.startAt,
        ),
        throwsStateError,
      );
      expect(find.text('Tổng quan - Cơ sở Cầu Giấy'), findsOneWidget);
    },
  );
}
