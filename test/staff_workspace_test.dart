import 'support/test_access.dart';

import 'package:ktgk/core/security/access_scope.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';
import 'package:ktgk/core/models/appointment.dart';
import 'package:ktgk/core/models/shop_settings.dart';
import 'package:ktgk/features/booking/application/appointment_provider.dart';
import 'package:ktgk/features/booking/data/mock_appointment_repository.dart';
import 'package:ktgk/features/catalog/application/service_provider.dart';
import 'package:ktgk/features/catalog/data/mock_service_repository.dart';
import 'package:ktgk/features/users/application/user_provider.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';
import 'package:ktgk/features/staff/presentation/staff_schedule_screen.dart';
import 'package:ktgk/features/staff/presentation/staff_customers_screen.dart';

void main() {
  Appointment item(
    String id,
    int hour, {
    AppointmentStatus status = AppointmentStatus.confirmed,
    String staff = 'staff-01',
    bool hidden = false,
  }) => Appointment(
    branchId: 'branch-01',
    id: id,
    customerId: 'customer-01',
    staffId: staff,
    serviceIds: ['service-01'],
    serviceNamesSnapshot: [id],
    startAt: DateTime.utc(2030, 1, 1, hour),
    endAt: DateTime.utc(2030, 1, 1, hour + 1),
    totalPriceVnd: 150000,
    status: status,
    isHiddenByCustomer: hidden,
  );

  test('Staff transitions reject invalid changes and preserve snapshots', () {
    final repo = MockAppointmentRepository(
      initialData: [
        item('confirmed', 2),
        item('cancelled', 4, status: AppointmentStatus.cancelled),
      ],
    );
    expect(
      repo.updateStaffStatus('confirmed', AppointmentStatus.completed),
      isTrue,
    );
    expect(
      repo.updateStaffStatus('confirmed', AppointmentStatus.completed),
      isFalse,
    );
    expect(
      () => repo.updateStaffStatus('confirmed', AppointmentStatus.noShow),
      throwsStateError,
    );
    expect(
      () => repo.updateStaffStatus('cancelled', AppointmentStatus.completed),
      throwsStateError,
    );
    expect(
      () => repo.updateStaffStatus('missing', AppointmentStatus.noShow),
      throwsStateError,
    );
    expect(
      () => repo.updateStaffStatus('confirmed', AppointmentStatus.pending),
      throwsArgumentError,
    );
    expect(repo.getAll().first.totalPriceVnd, 150000);
  });

  testWidgets(
    'Today filters Vietnam day and completion/noShow update derived customers',
    (tester) async {
      final services = ServiceProvider(
        MockServiceRepository(),
        access: testAccess(),
      );
      final users = UserProvider(MockUserRepository(), access: testAccess());
      final auth = AuthController(MockAuthRepository());
      addTearDown(auth.dispose);
      await tester.runAsync(
        () => auth.signIn(email: 'staff@exampler.com', password: 'staff123'),
      );
      final repo = MockAppointmentRepository(
        initialData: [
          item('Complete me', 2),
          item('No show', 4),
          item(
            'Hidden completed',
            0,
            status: AppointmentStatus.completed,
            hidden: true,
          ),
          item('Yesterday', -2),
          item('Other staff', 2, staff: 'staff-02'),
        ],
      );
      final booking = AppointmentProvider(
        repo,
        services: services,
        users: users,
        settings: ShopSettings(
          branchId: 'branch-01',
          openingMinute: 480,
          closingMinute: 1200,
        ),
        clock: () => DateTime.utc(2030, 1, 1, 5),
        access: AccessScope(() => auth.currentUser),
      );
      addTearDown(booking.dispose);
      addTearDown(users.dispose);
      addTearDown(services.dispose);
      Future<void> show(Widget screen) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: booking),
              ChangeNotifierProvider.value(value: users),
              ChangeNotifierProvider.value(value: auth),
            ],
            child: MaterialApp(home: screen),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(const StaffScheduleScreen());
      expect(find.text('Other staff'), findsNothing);
      expect(
        find.text('Yesterday'),
        findsOneWidget,
      ); // 22:00 UTC previous day = 05:00 Vietnam today.
      final completeCard = find.byKey(const ValueKey('Complete me'));
      await tester.ensureVisible(
        find.descendant(of: completeCard, matching: find.text('Hoàn thành ca')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: completeCard, matching: find.text('Hoàn thành ca')),
      );
      await tester.pumpAndSettle();
      expect(repo.getAll().first.status, AppointmentStatus.completed);
      final noShowCard = find.byKey(const ValueKey('No show'));
      await tester.ensureVisible(
        find.descendant(of: noShowCard, matching: find.text('Khách không đến')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(of: noShowCard, matching: find.text('Khách không đến')),
      );
      await tester.pumpAndSettle();
      expect(repo.getAll()[1].status, AppointmentStatus.noShow);
      await tester.ensureVisible(noShowCard);
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: noShowCard, matching: find.text('Tổng tiền: 0đ')),
        findsOneWidget,
      );
      expect(repo.getAll()[1].totalPriceVnd, 150000);
      await show(const StaffCustomersScreen());
      expect(find.text('Customer Demo'), findsOneWidget);
      expect(find.text('2 lần'), findsOneWidget);
      expect(find.text('Lần ghé gần nhất: 1/1/2030'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
