import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/models/appointment.dart';
import 'package:ktgk/core/routing/app_router.dart';
import 'package:ktgk/core/routing/booking_arguments.dart';
import 'package:ktgk/features/booking/data/mock_appointment_repository.dart';
import 'package:ktgk/features/booking/presentation/booking_calendar.dart';
import 'package:ktgk/features/booking/presentation/customer_booking_screen.dart';
import 'package:ktgk/features/catalog/presentation/customer_services_screen.dart';
import 'package:ktgk/features/reviews/data/review_repository.dart';
import 'package:ktgk/features/reviews/presentation/reviews_screen.dart';

import 'support/booking_test_scope.dart';
import 'support/customer_fixture.dart';

Appointment appointment({
  String id = 'completed',
  String customer = 'customer-01',
  AppointmentStatus status = AppointmentStatus.completed,
}) => Appointment(
  id: id,
  branchId: 'branch-01',
  customerId: customer,
  staffId: 'staff-01',
  serviceIds: ['service-01'],
  serviceNamesSnapshot: ['Cắt tóc'],
  startAt: DateTime.utc(
    2026,
    1,
    id == 'completed'
        ? 1
        : id == 'other'
        ? 2
        : 3,
  ),
  endAt: DateTime.utc(
    2026,
    1,
    id == 'completed'
        ? 1
        : id == 'other'
        ? 2
        : 3,
    1,
  ),
  totalPriceVnd: 100000,
  status: status,
);

void main() {
  test(
    'reviews enforce owner/completion, independent targets and no duplicates',
    () async {
      final auth = customerFixtureAuth();
      final appointments = MockAppointmentRepository(
        initialData: [
          appointment(),
          appointment(id: 'other', customer: 'other'),
          appointment(id: 'pending', status: AppointmentStatus.confirmed),
        ],
      );
      final reviews = ReviewRepository(auth, appointments);
      await expectLater(
        reviews.submit('other', 'branch', 5, ''),
        throwsStateError,
      );
      await expectLater(
        reviews.submit('pending', 'staff', 5, ''),
        throwsStateError,
      );
      await reviews.submit('completed', 'branch', 4, 'Không gian tốt');
      await reviews.submit('completed', 'staff', 5, 'Tóc đẹp');
      await expectLater(
        reviews.submit('completed', 'branch', 5, ''),
        throwsStateError,
      );
      expect((await reviews.list('branch', 'branch-01'))['average'], 4);
      expect((await reviews.list('staff', 'staff-01'))['average'], 5);
      expect(appointments.getAll().first.rating, 5);
      auth.signOut();
      await expectLater(
        reviews.submit('completed', 'staff', 5, ''),
        throwsStateError,
      );
      auth.dispose();
    },
  );

  testWidgets(
    'service details show price/process/samples and preselect booking',
    (tester) async {
      await tester.pumpWidget(
        const BookingTestScope(
          child: MaterialApp(
            onGenerateRoute: AppRouter.generateRoute,
            home: CustomerServicesScreen(
              arguments: ServiceArguments(
                serviceId: 'service-01',
                branchId: 'branch-01',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cách thức thực hiện'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Mẫu tham khảo'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('Mẫu tham khảo'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Mohican'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mohican'));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerBookingScreen), findsOneWidget);
      final screen = tester.widget<CustomerBookingScreen>(
        find.byType(CustomerBookingScreen),
      );
      expect(screen.initialServiceId, 'service-01');
      expect(screen.initialBranchId, 'branch-01');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('month calendar highlights today and changes selected day', (
    tester,
  ) async {
    DateTime? selected;
    final today = DateTime(2026, 10, 12);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BookingCalendar(
            date: today,
            today: today,
            onChanged: (day) => selected = day,
          ),
        ),
      ),
    );
    final calendar = tester.widget<CalendarDatePicker>(
      find.byType(CalendarDatePicker),
    );
    expect(calendar.currentDate, today);
    expect(calendar.firstDate, today);
    await tester.tap(find.text('13').first);
    await tester.pumpAndSettle();
    expect(selected, DateTime(2026, 10, 13));
    calendar.onDisplayedMonthChanged!(DateTime(2026, 11));
    await tester.pump();
    expect(find.text('Tháng 11/2026'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer submits independent branch and staff ratings', (
    tester,
  ) async {
    final auth = customerFixtureAuth();
    final reviews = ReviewRepository(
      auth,
      MockAppointmentRepository(initialData: [appointment()]),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider.value(value: reviews),
          ChangeNotifierProvider.value(value: auth),
        ],
        child: const MaterialApp(
          home: ReviewsScreen(
            arguments: ReviewsArguments(
              branchId: 'branch-01',
              staffId: 'staff-01',
              appointmentId: 'completed',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gửi đánh giá'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi đánh giá'));
    await tester.pumpAndSettle();
    expect((await reviews.list('branch', 'branch-01'))['count'], 1);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Thợ cắt'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Thợ cắt'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gửi đánh giá'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi đánh giá'));
    await tester.pumpAndSettle();
    expect((await reviews.list('staff', 'staff-01'))['count'], 1);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });
}
