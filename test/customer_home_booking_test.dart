import 'support/customer_fixture.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/models/appointment.dart';
import 'package:ktgk/core/models/promotion.dart';
import 'package:ktgk/core/routing/app_routes.dart';
import 'package:ktgk/features/booking/application/appointment_provider.dart';
import 'package:ktgk/features/booking/presentation/customer_booking_screen.dart';
import 'package:ktgk/features/customer/presentation/customer_home_screen.dart';

import 'support/booking_test_scope.dart';

void main() {
  Future<void> start(WidgetTester tester, {bool empty = false}) async {
    await tester.pumpWidget(
      BookingTestScope(
        empty: empty,
        child: ChangeNotifierProvider(
          create: (_) => customerFixtureAuth(),
          child: MaterialApp(
            routes: {AppRoutes.booking: (_) => const CustomerBookingScreen()},
            home: const Scaffold(
              body: CustomerHomeScreen(
                promotions: [
                  Promotion(
                    id: 'offer',
                    title: 'Marketing test',
                    subtitle: 'Display only',
                    imageUrl: '',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Real appointment details and cancellation hide the card', (
    tester,
  ) async {
    await start(tester);
    expect(find.text('Combo Cắt + Gội'), findsOneWidget);
    expect(find.text('09:00 · 1/1/2030'), findsOneWidget);
    expect(find.text('Thợ: Nguyễn Minh Hùng'), findsOneWidget);
    expect(find.text('Đổi giờ'), findsNothing);
    expect(find.text('MẪU'), findsNothing);
    final provider = tester
        .element(find.byType(CustomerHomeScreen))
        .read<AppointmentProvider>();
    await tester.ensureVisible(find.text('Hủy lịch'));
    await tester.tap(find.text('Hủy lịch'));
    await tester.pumpAndSettle();
    expect(
      provider.getByCustomerId('customer-01').single.status,
      AppointmentStatus.cancelled,
    );
    expect(find.text('Lịch hẹn sắp tới'), findsNothing);
  });

  testWidgets('Primary and model-driven banner buttons both open Booking', (
    tester,
  ) async {
    await start(tester, empty: true);
    expect(find.text('Lịch hẹn sắp tới'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('primary-booking')));
    await tester.pumpAndSettle();
    expect(find.byType(CustomerBookingScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(CustomerBookingScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.text('Marketing test'), findsOneWidget);
    final banner = find.descendant(
      of: find.byType(PageView),
      matching: find.widgetWithText(FilledButton, 'Đặt lịch ngay'),
    );
    await tester.ensureVisible(banner);
    await tester.tap(banner);
    await tester.pumpAndSettle();
    expect(find.byType(CustomerBookingScreen), findsOneWidget);
  });
}
