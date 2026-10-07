import 'support/booking_test_scope.dart';
import 'support/test_access.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/models/appointment.dart';
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
  late MockAppointmentRepository repository;
  late AppointmentProvider booking;
  final day = DateTime.utc(2026, 10, 7);
  setUp(() {
    services = ServiceProvider(MockServiceRepository(), access: testAccess());
    users = UserProvider(MockUserRepository(), access: testAccess());
    users.update(users.getById('staff-02')!.copyWith(isApproved: true));
    repository = MockAppointmentRepository(initialData: []);
    booking = AppointmentProvider(
      repository,
      services: services,
      users: users,
      settings: ShopSettings(
        branchId: 'branch-01',
        openingMinute: 480,
        closingMinute: 600,
      ),
      clock: () => DateTime.utc(2026, 10, 6),
      access: testAccess(),
    );
  });
  tearDown(() {
    booking.dispose();
    services.dispose();
    users.dispose();
  });
  List slots() => booking.availableSlots(
    staffId: 'staff-01',
    serviceId: 'service-01',
    date: day,
  );

  test('Vietnam opening time, full duration and closing boundary', () {
    final available = slots();
    expect(available, hasLength(2));
    expect(available.first.start, DateTime.utc(2026, 10, 7, 1));
    expect(available.last.end, DateTime.utc(2026, 10, 7, 2, 30));
    expect(
      booking.availableSlots(
        staffId: 'staff-02',
        serviceId: 'service-04',
        date: day,
      ),
      hasLength(4),
    );
    expect(
      booking.availableSlots(
        staffId: 'admin-01',
        serviceId: 'service-01',
        date: day,
      ),
      isEmpty,
    );
    expect(
      booking.availableSlots(
        staffId: 'staff-01',
        serviceId: 'service-01',
        date: DateTime.utc(2026, 1, 1),
      ),
      isEmpty,
    );
  });

  test(
    'Booking rejects stale slot; adjacency works and cancellation frees time',
    () {
      final available = slots();
      var notifications = 0;
      booking.addListener(() => notifications++);
      final first = booking.book(
        customerId: 'customer-01',
        staffId: 'staff-01',
        serviceId: 'service-01',
        startAt: available.first.start,
      );
      expect(slots(), hasLength(1));
      expect(
        () => booking.book(
          customerId: 'other',
          staffId: 'staff-01',
          serviceId: 'service-01',
          startAt: available.first.start,
        ),
        throwsStateError,
      );
      booking.book(
        customerId: 'customer-01',
        staffId: 'staff-01',
        serviceId: 'service-01',
        startAt: available.last.start,
      );
      expect(slots(), isEmpty);
      expect(booking.getByCustomerId('customer-01'), hasLength(2));
      expect(booking.getByStaffId('staff-01'), hasLength(2));
      booking.cancel(first.id);
      booking.cancel(first.id);
      expect(slots(), hasLength(1));
      expect(notifications, 3);
      expect(() => repository.getAll().clear(), throwsUnsupportedError);
    },
  );

  test('Off-grid overlaps and closed dates are excluded', () {
    repository.create(
      Appointment(
        branchId: 'branch-01',
        id: 'busy',
        customerId: 'c',
        staffId: 'staff-01',
        serviceIds: ['s'],
        serviceNamesSnapshot: ['Test'],
        startAt: DateTime.utc(2026, 10, 7, 1, 30),
        endAt: DateTime.utc(2026, 10, 7, 2),
        totalPriceVnd: 0,
      ),
    );
    expect(slots(), isEmpty);
    final closed = AppointmentProvider(
      repository,
      services: services,
      users: users,
      settings: ShopSettings(
        branchId: 'branch-01',
        openingMinute: 480,
        closingMinute: 1200,
        closedDates: ['2026-10-07'],
      ),
      clock: () => DateTime.utc(2026),
      access: testAccess(),
    );
    addTearDown(closed.dispose);
    expect(
      closed.availableSlots(
        staffId: 'staff-01',
        serviceId: 'service-01',
        date: day,
      ),
      isEmpty,
    );
    final weekly = AppointmentProvider(
      repository,
      services: services,
      users: users,
      settings: ShopSettings(
        branchId: 'branch-01',
        openingMinute: 480,
        closingMinute: 1200,
        closedWeekdays: [day.weekday],
      ),
      clock: () => DateTime.utc(2026),
      access: testAccess(),
    );
    addTearDown(weekly.dispose);
    expect(
      weekly.availableSlots(
        staffId: 'staff-01',
        serviceId: 'service-01',
        date: day,
      ),
      isEmpty,
    );
  });

  testWidgets('Customer selects service, staff and time then confirms once', (
    tester,
  ) async {
    await tester.pumpWidget(
      BookingTestScope(
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: services),
            ChangeNotifierProvider.value(value: users),
            ChangeNotifierProvider.value(value: booking),
          ],
          child: const MaterialApp(
            home: CustomerBookingScreen(initialBranchId: 'branch-01'),
          ),
        ),
      ),
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
    await tester.tap(find.byType(ChoiceChip).first);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Xác nhận'));
    await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
    await tester.pumpAndSettle();
    expect(booking.appointments, hasLength(1));
    expect(booking.appointments.single.customerId, 'customer-01');
    expect(find.text('Đặt lịch thành công!'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Xác nhận'))
          .onPressed,
      isNull,
    );
  });
}
