import 'support/booking_test_scope.dart';
import 'support/test_access.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/models/shop_settings.dart';
import 'package:ktgk/features/settings/application/shop_settings_provider.dart';
import 'package:ktgk/features/settings/presentation/shop_settings_editors.dart';
import 'package:ktgk/features/manager/presentation/manager_settings_screen.dart';
import 'package:ktgk/features/booking/application/appointment_provider.dart';
import 'package:ktgk/features/booking/data/mock_appointment_repository.dart';
import 'package:ktgk/features/booking/presentation/customer_booking_screen.dart';
import 'package:ktgk/features/catalog/application/service_provider.dart';
import 'package:ktgk/features/catalog/data/mock_service_repository.dart';
import 'package:ktgk/features/users/application/user_provider.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';

void main() {
  test('Settings notify booking, reject stale hours/dates and keep appointments', () {
    final settings = ShopSettingsProvider(
      settings: ShopSettings(
        branchId: 'branch-01',
        openingMinute: 480,
        closingMinute: 600,
      ),
      access: testAccess(),
    );
    final services = ServiceProvider(
      MockServiceRepository(),
      access: testAccess(),
    );
    final users = UserProvider(MockUserRepository(), access: testAccess());
    final booking = AppointmentProvider(
      MockAppointmentRepository(initialData: []),
      services: services,
      users: users,
      shopSettings: settings,
      clock: () => DateTime.utc(2030),
      access: testAccess(),
    );
    var disposed = false;
    addTearDown(() {
      if (!disposed) booking.dispose();
      settings.dispose();
      services.dispose();
      users.dispose();
    });
    final day = DateTime.utc(2030, 1, 2);
    final old = booking
        .availableSlots(staffId: 'staff-01', serviceId: 'service-01', date: day)
        .first;
    var notifications = 0;
    booking.addListener(() => notifications++);
    settings.updateWorkingHours(
      const TimeOfDay(hour: 9, minute: 0),
      const TimeOfDay(hour: 11, minute: 0),
    );
    expect(notifications, 1);
    expect(
      booking
          .availableSlots(
            staffId: 'staff-01',
            serviceId: 'service-01',
            date: day,
          )
          .first
          .start
          .hour,
      2,
    );
    expect(
      () => booking.book(
        customerId: 'c',
        staffId: 'staff-01',
        serviceId: 'service-01',
        startAt: old.start,
      ),
      throwsStateError,
    );
    expect(
      () => settings.updateWorkingHours(
        const TimeOfDay(hour: 12, minute: 0),
        const TimeOfDay(hour: 8, minute: 0),
      ),
      throwsArgumentError,
    );
    expect(settings.openTime.hour, 9);
    final slot = booking
        .availableSlots(staffId: 'staff-01', serviceId: 'service-01', date: day)
        .first;
    booking.book(
      customerId: 'c',
      staffId: 'staff-01',
      serviceId: 'service-01',
      startAt: slot.start,
    );
    settings.addClosedDate(day);
    settings.addClosedDate(DateTime(2030, 1, 2, 18));
    expect(settings.closedDates, ['2030-01-02']);
    expect(
      booking.availableSlots(
        staffId: 'staff-01',
        serviceId: 'service-01',
        date: day,
      ),
      isEmpty,
    );
    expect(
      () => booking.book(
        customerId: 'walk-in',
        customerName: 'Guest',
        staffId: 'staff-01',
        serviceId: 'service-01',
        startAt: slot.end,
      ),
      throwsStateError,
    );
    expect(booking.appointments, hasLength(1));
    settings.removeClosedDate(day);
    expect(
      booking.availableSlots(
        staffId: 'staff-01',
        serviceId: 'service-01',
        date: day,
      ),
      isNotEmpty,
    );
    booking
        .dispose(); // Listener removed; editing shared settings is still safe.
    disposed = true;
    settings.addClosedDate(DateTime(2030, 1, 3));
  });

  testWidgets('Settings open native pickers and manage closed dates', (
    tester,
  ) async {
    final settings = ShopSettingsProvider(access: testAccess());
    addTearDown(settings.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: settings,
        child: const MaterialApp(home: ManagerSettingsScreen()),
      ),
    );
    await tester.tap(find.text('Giờ hoạt động'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkingHoursDialog), findsOneWidget);
    await tester.tap(find.text('Giờ mở cửa'));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkingHoursDialog), findsNothing);
    await tester.tap(find.text('Cấu hình ngày nghỉ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thêm ngày nghỉ'));
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(settings.closedDates, hasLength(1));
    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();
    expect(settings.closedDates, isEmpty);
    expect(find.text('Chưa có ngày nghỉ cụ thể.'), findsOneWidget);
  });

  for (final walkIn in [false, true]) {
    testWidgets(
      '${walkIn ? 'Admin walk-in' : 'Customer'} slot chips react immediately when day closes',
      (tester) async {
        final settings = ShopSettingsProvider(access: testAccess());
        final services = ServiceProvider(
          MockServiceRepository(),
          access: testAccess(),
        );
        final users = UserProvider(MockUserRepository(), access: testAccess());
        final booking = AppointmentProvider(
          MockAppointmentRepository(initialData: []),
          services: services,
          users: users,
          shopSettings: settings,
          clock: () => DateTime.utc(2030),
          access: testAccess(),
        );
        addTearDown(() {
          booking.dispose();
          settings.dispose();
          services.dispose();
          users.dispose();
        });
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
        await tester.tap(fields.at(1));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Combo Cắt + Gội · 45 phút').last);
        await tester.pumpAndSettle();
        await tester.tap(fields.last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Nguyễn Minh Hùng').last);
        await tester.pumpAndSettle();
        expect(find.byType(ChoiceChip), findsWidgets);
        settings.addClosedDate(booking.today);
        await tester.pumpAndSettle();
        expect(find.byType(ChoiceChip), findsNothing);
        expect(
          find.text('Không còn giờ trống trong ngày này.'),
          findsOneWidget,
        );
        settings.removeClosedDate(booking.today);
        await tester.pumpAndSettle();
        expect(find.byType(ChoiceChip), findsWidgets);
      },
    );
  }
}
