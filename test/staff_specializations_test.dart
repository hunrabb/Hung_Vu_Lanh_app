import 'support/booking_test_scope.dart';
import 'support/test_access.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/models/shop_settings.dart';
import 'package:ktgk/features/booking/application/appointment_provider.dart';
import 'package:ktgk/features/booking/data/mock_appointment_repository.dart';
import 'package:ktgk/features/booking/presentation/customer_booking_screen.dart';
import 'package:ktgk/features/catalog/application/service_provider.dart';
import 'package:ktgk/features/catalog/data/mock_service_repository.dart';
import 'package:ktgk/features/users/application/user_provider.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';

void main() {
  late ServiceProvider services;
  late UserProvider users;
  late AppointmentProvider booking;
  setUp(() {
    services = ServiceProvider(MockServiceRepository(), access: testAccess());
    users = UserProvider(MockUserRepository(), access: testAccess());
    users.update(users.getById('staff-02')!.copyWith(isApproved: true));
    booking = AppointmentProvider(
      MockAppointmentRepository(initialData: []),
      services: services,
      users: users,
      settings: ShopSettings(
        branchId: 'branch-01',
        openingMinute: 480,
        closingMinute: 1200,
      ),
      clock: () => DateTime.utc(2030),
      access: testAccess(),
    );
  });
  tearDown(() {
    booking.dispose();
    services.dispose();
    users.dispose();
  });

  test('Engine rejects wrong specialties and stale staff capabilities', () {
    final date = DateTime.utc(2030, 1, 2);
    expect(
      booking.availableSlots(
        staffId: 'staff-01',
        serviceId: 'service-04',
        date: date,
      ),
      isEmpty,
    );
    final valid = booking
        .availableSlots(
          staffId: 'staff-02',
          serviceId: 'service-04',
          date: date,
        )
        .first;
    expect(
      () => booking.book(
        customerId: 'c',
        staffId: 'staff-01',
        serviceId: 'service-04',
        startAt: valid.start,
      ),
      throwsStateError,
    );
    users.update(
      users.getById('staff-02')!.copyWith(specializedCategoryIds: []),
    );
    expect(
      () => booking.book(
        customerId: 'walk-in',
        customerName: 'Guest',
        staffId: 'staff-02',
        serviceId: 'service-04',
        startAt: valid.start,
      ),
      throwsStateError,
    );
    expect(booking.appointments, isEmpty);
  });

  for (final walkIn in [false, true]) {
    testWidgets(
      '${walkIn ? 'Admin' : 'Customer'} filters staff and clears selection on service change',
      (tester) async {
        await tester.pumpWidget(
          BookingTestScope(
            manager: walkIn,
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: services),
                ChangeNotifierProvider.value(value: users),
                ChangeNotifierProvider.value(value: booking),
              ],
              child: MaterialApp(
                home: CustomerBookingScreen(
                  walkIn: walkIn,
                  initialBranchId: 'branch-01',
                ),
              ),
            ),
          ),
        );
        final fields = find.byType(DropdownButtonFormField<String>);
        expect(
          tester.widget<DropdownButtonFormField<String>>(fields.last).onChanged,
          isNull,
        );
        await tester.tap(fields.at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Combo Cắt + Gội · 45 phút').last);
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<DropdownButton<String>>(
                find.byType(DropdownButton<String>).last,
              )
              .items!
              .map((item) => item.value),
          ['staff-01', 'staff-03'],
        );
        await tester.tap(fields.last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nguyễn Minh Hùng').last);
        await tester.pumpAndSettle();
        if (!walkIn) {
          await tester.tap(fields.first);
          await tester.pumpAndSettle();
          await tester.tap(find.text('Cơ sở Đống Đa').last);
          await tester.pumpAndSettle();
        }
        await tester.tap(fields.at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nhuộm màu thời trang · 120 phút').last);
        await tester.pumpAndSettle();
        final filtered = tester.widget<DropdownButtonFormField<String>>(
          fields.last,
        );
        expect(
          tester
              .widget<DropdownButton<String>>(
                find.byType(DropdownButton<String>).last,
              )
              .items!
              .map((item) => item.value),
          walkIn ? <String>[] : ['staff-02'],
        );
        expect(filtered.initialValue, isNull);
        users.update(
          users.getById('staff-02')!.copyWith(specializedCategoryIds: []),
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<DropdownButtonFormField<String>>(fields.last).onChanged,
          isNull,
        );
        expect(
          find.text('Chưa có nhân viên phù hợp với dịch vụ này.'),
          findsOneWidget,
        );
      },
    );
  }
}
