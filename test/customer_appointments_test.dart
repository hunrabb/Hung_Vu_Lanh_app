import 'support/customer_fixture.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/routing/app_routes.dart';
import 'package:ktgk/features/booking/application/appointment_provider.dart';
import 'package:ktgk/features/booking/presentation/customer_booking_screen.dart';
import 'package:ktgk/features/customer/presentation/customer_main.dart';
import 'package:ktgk/features/customer/presentation/customer_appointments_screen.dart';

import 'support/booking_test_scope.dart';

void main() {
  testWidgets('Empty appointments offers booking navigation', (tester) async {
    await tester.pumpWidget(
      BookingTestScope(
        empty: true,
        child: MaterialApp(
          home: const Scaffold(body: CustomerAppointmentsScreen()),
          routes: {AppRoutes.booking: (_) => const CustomerBookingScreen()},
        ),
      ),
    );
    expect(find.text('Bạn chưa có lịch hẹn nào'), findsOneWidget);
    await tester.tap(find.text('Đặt lịch ngay'));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerBookingScreen), findsOneWidget);
  });

  testWidgets(
    'New booking and cancellation synchronize Home and History both ways',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        BookingTestScope(
          child: ChangeNotifierProvider(
            create: (_) => customerFixtureAuth(),
            child: const MaterialApp(home: CustomerMain()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final provider = tester
          .element(find.byType(CustomerMain))
          .read<AppointmentProvider>();
      Future<void> tab(IconData icon) async {
        await tester.tap(
          find.descendant(
            of: find.byType(BottomNavigationBar),
            matching: find.byIcon(icon),
          ),
        );
        await tester.pumpAndSettle();
      }

      await tester.ensureVisible(find.text('Hủy lịch'));
      await tester.tap(find.text('Hủy lịch'));
      await tester.pumpAndSettle();
      await tab(Icons.calendar_today_outlined);
      expect(find.text('Đã hủy'), findsOneWidget);
      expect(find.text('Hủy lịch'), findsNothing);
      expect(find.text('Lịch sử (1)'), findsOneWidget);
      final slot = provider
          .availableSlots(
            staffId: 'staff-05',
            serviceId: 'service-02',
            date: DateTime.utc(2030, 1, 2),
          )
          .first;
      provider.book(
        customerId: 'customer-01',
        staffId: 'staff-05',
        serviceId: 'service-02',
        startAt: slot.start,
      );
      provider.book(
        customerId: 'other-customer',
        staffId: 'staff-01',
        serviceId: 'service-02',
        startAt: slot.start,
      );
      await tester.pumpAndSettle();
      expect(find.text('Sắp tới (1)'), findsOneWidget);
      expect(find.text('Gội đầu thư giãn'), findsOneWidget);
      await tab(Icons.home_outlined);
      expect(find.text('Lịch hẹn sắp tới'), findsOneWidget);
      expect(find.text('Gội đầu thư giãn'), findsOneWidget);
      await tab(Icons.calendar_today_outlined);
      await tester.ensureVisible(find.text('Hủy lịch'));
      await tester.tap(find.text('Hủy lịch'));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(find.text('Lịch sử (2)'), findsOneWidget);
      expect(find.text('Hủy lịch'), findsNothing);
      await tab(Icons.home_outlined);
      expect(find.text('Lịch hẹn sắp tới'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
