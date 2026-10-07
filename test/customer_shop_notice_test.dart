import 'support/customer_fixture.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/features/booking/application/appointment_provider.dart';
import 'package:ktgk/features/customer/presentation/customer_home_screen.dart';
import 'package:ktgk/features/settings/application/shop_settings_provider.dart';
import 'package:ktgk/shared/widgets/custom_button.dart';

import 'support/booking_test_scope.dart';

void main() {
  testWidgets(
    'Home watches hours and disables every booking CTA on a closed day',
    (tester) async {
      await tester.pumpWidget(
        BookingTestScope(
          empty: true,
          child: ChangeNotifierProvider(
            create: (_) => customerFixtureAuth(),
            child: const MaterialApp(
              home: Scaffold(body: CustomerHomeScreen()),
            ),
          ),
        ),
      );
      final context = tester.element(find.byType(CustomerHomeScreen));
      final shop = context.read<ShopSettingsProvider>();
      final booking = context.read<AppointmentProvider>();
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cơ sở Cầu Giấy').last);
      await tester.pumpAndSettle();
      expect(find.text('Giờ hoạt động: 08:00 - 20:00'), findsOneWidget);
      shop.updateWorkingHours(
        const TimeOfDay(hour: 9, minute: 30),
        const TimeOfDay(hour: 18, minute: 0),
      );
      await tester.pumpAndSettle();
      expect(find.text('Giờ hoạt động: 09:30 - 18:00'), findsOneWidget);
      shop.addClosedDate(booking.today);
      await tester.pumpAndSettle();
      expect(
        find.text('Hôm nay cửa hàng tạm nghỉ. Hẹn gặp lại bạn vào ngày mai!'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<CustomButton>(find.byKey(const ValueKey('primary-booking')))
            .onPressed,
        isNull,
      );
      final banner = find.descendant(
        of: find.byType(PageView),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(banner.first).onPressed, isNull);
      shop.removeClosedDate(booking.today);
      await tester.pumpAndSettle();
      expect(
        find.text('Hôm nay cửa hàng tạm nghỉ. Hẹn gặp lại bạn vào ngày mai!'),
        findsNothing,
      );
      expect(
        tester
            .widget<CustomButton>(find.byKey(const ValueKey('primary-booking')))
            .onPressed,
        isNotNull,
      );
    },
  );
}
