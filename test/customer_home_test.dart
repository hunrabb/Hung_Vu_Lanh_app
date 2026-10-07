import 'support/booking_test_scope.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktgk/core/routing/app_router.dart';
import 'package:ktgk/core/routing/app_routes.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';
import 'package:ktgk/features/customer/presentation/customer_home_screen.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets(
    'Small phone scrolls all Home sections without overflow and logs out',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final auth = AuthController(MockAuthRepository());
      addTearDown(auth.dispose);
      await tester.runAsync(
        () =>
            auth.signIn(email: 'customer@example.com', password: 'customer123'),
      );
      await tester.pumpWidget(
        BookingTestScope(
          child: ChangeNotifierProvider.value(
            value: auth,
            child: MaterialApp(
              initialRoute: AppRoutes.customerHome,
              onGenerateRoute: AppRouter.generateRoute,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Xin chào, Customer Demo!'), findsOneWidget);
      expect(find.text('Điểm thưởng: 150⭐'), findsOneWidget);
      expect(find.text('Lịch hẹn sắp tới'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.byType(PageView));
      await tester.drag(find.byType(PageView), const Offset(-250, 0));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final label in ['Dịch vụ', 'Thợ nổi bật', 'Một diện mạo mới']) {
        await tester.ensureVisible(find.text(label));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
      expect(find.byTooltip('Đăng xuất'), findsNothing);
      final navigation = find.byType(BottomNavigationBar);
      await tester.tap(
        find.descendant(
          of: navigation,
          matching: find.byIcon(Icons.calendar_today_outlined),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lịch hẹn của bạn'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.descendant(
          of: navigation,
          matching: find.byIcon(Icons.home_outlined),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Một diện mạo mới'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(
        find.descendant(
          of: navigation,
          matching: find.byIcon(Icons.person_outline),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Hồ sơ của bạn'), findsOneWidget);
      expect(find.text('customer@example.com'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Đăng xuất'));
      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();
      expect(auth.currentUser, isNull);
      expect(find.text('Welcome Back'), findsOneWidget);
    },
  );

  testWidgets('No appointment hides upcoming card', (tester) async {
    final auth = AuthController(MockAuthRepository());
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      BookingTestScope(
        empty: true,
        child: ChangeNotifierProvider.value(
          value: auth,
          child: const MaterialApp(home: Scaffold(body: CustomerHomeScreen())),
        ),
      ),
    );
    expect(find.text('Lịch hẹn sắp tới'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
