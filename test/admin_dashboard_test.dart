import 'support/test_access.dart';
import 'support/booking_test_scope.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/models/appointment.dart';
import 'package:ktgk/core/models/shop_settings.dart';
import 'package:ktgk/features/manager/presentation/manager_dashboard_screen.dart';
import 'package:ktgk/features/booking/application/appointment_provider.dart';
import 'package:ktgk/features/booking/data/mock_appointment_repository.dart';
import 'package:ktgk/features/catalog/application/service_provider.dart';
import 'package:ktgk/features/catalog/data/mock_service_repository.dart';
import 'package:ktgk/features/users/application/user_provider.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';

void main() {
  testWidgets(
    'Dashboard derives today metrics, sorts real walk-ins and reacts to changes on small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime.utc(2030, 1, 2, 3);
      final seeds = MockAppointmentRepository(now: now).getAll();
      Appointment item(String id, DateTime start, AppointmentStatus status) =>
          Appointment(
            branchId: 'branch-01',
            id: id,
            customerId: 'walk-in',
            customerName: id,
            staffId: 'staff-01',
            serviceIds: ['s'],
            serviceNamesSnapshot: ['Dịch vụ thật'],
            startAt: start,
            endAt: start.add(const Duration(minutes: 30)),
            totalPriceVnd: 999999,
            status: status,
          );
      final users = UserProvider(MockUserRepository(), access: testAccess());
      final services = ServiceProvider(
        MockServiceRepository(),
        access: testAccess(),
      );
      final booking = AppointmentProvider(
        MockAppointmentRepository(
          initialData: [
            seeds.first.copyWith(
              isHiddenByCustomer: true,
              isHiddenByStaff: true,
            ),
            seeds.last,
            item(
              'Early Guest',
              DateTime.utc(2030, 1, 2, 1),
              AppointmentStatus.pending,
            ),
            item(
              'Cancelled Guest',
              DateTime.utc(2030, 1, 2, 5),
              AppointmentStatus.cancelled,
            ),
            item(
              'Previous Day',
              DateTime.utc(2030, 1, 1, 16),
              AppointmentStatus.pending,
            ),
          ],
        ),
        services: services,
        users: users,
        settings: ShopSettings(
          branchId: 'branch-01',
          openingMinute: 480,
          closingMinute: 1200,
        ),
        clock: () => now,
        access: testAccess(),
      );
      addTearDown(booking.dispose);
      addTearDown(users.dispose);
      addTearDown(services.dispose);
      await tester.pumpWidget(
        BookingTestScope(
          manager: true,
          child: MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: booking),
              ChangeNotifierProvider.value(value: users),
            ],
            child: const MaterialApp(
              home: Scaffold(body: ManagerDashboardScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hôm nay, 2 Tháng 1'), findsOneWidget);
      expect(find.text('150.000đ'), findsOneWidget);
      expect(find.text('4 lịch'), findsOneWidget);
      expect(find.text('1 ca'), findsOneWidget);
      expect(find.text('Khách mới'), findsNothing);
      await tester.ensureVisible(find.text('Customer Demo - Combo Cắt + Gội'));
      await tester.pumpAndSettle();
      expect(find.text('Early Guest - Dịch vụ thật'), findsOneWidget);
      expect(find.text('Previous Day - Dịch vụ thật'), findsNothing);
      expect(
        tester.getTopLeft(find.text('Early Guest - Dịch vụ thật')).dy,
        lessThan(
          tester.getTopLeft(find.text('Customer Demo - Combo Cắt + Gội')).dy,
        ),
      );
      booking.updateStaffStatus(
        'appointment-demo-confirmed',
        AppointmentStatus.completed,
      );
      booking.cancel('Early Guest');
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.text('Không có lịch hẹn nào sắp tới trong hôm nay'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Không có lịch hẹn nào sắp tới trong hôm nay'),
        findsOneWidget,
      );
      await tester.ensureVisible(find.text('Doanh thu'));
      await tester.pumpAndSettle();
      expect(find.text('300.000đ'), findsOneWidget);
      expect(find.text('2 ca'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
