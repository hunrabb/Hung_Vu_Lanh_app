import 'support/booking_test_scope.dart';

import 'package:ktgk/core/security/access_scope.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktgk/core/routing/app_router.dart';
import 'package:ktgk/core/routing/app_routes.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/features/schedule/presentation/staff_main.dart';
import 'package:ktgk/features/manager/presentation/manager_main.dart';

void main() {
  late AuthController auth;
  late AccessScope access;
  late GlobalKey<NavigatorState> navigator;

  setUp(() {
    auth = AuthController(MockAuthRepository());
    access = AccessScope(() => auth.currentUser, changes: auth);
    navigator = GlobalKey<NavigatorState>();
  });
  tearDown(() {
    access.dispose();
    auth.dispose();
  });

  Future<void> start(WidgetTester tester, String route) async {
    await tester.pumpWidget(
      BookingTestScope(
        access: access,
        child: ChangeNotifierProvider.value(
          value: auth,
          child: MaterialApp(
            navigatorKey: navigator,
            initialRoute: route,
            onGenerateRoute: AppRouter.generateRoute,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Signed-out direct routes redirect to Login and clear history', (
    tester,
  ) async {
    await start(tester, AppRoutes.managerDashboard);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.byType(ManagerMain), findsNothing);
    expect(navigator.currentState!.canPop(), isFalse);
    navigator.currentState!.pushNamed(AppRoutes.booking);
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(find.text('Book an appointment'), findsNothing);
    expect(navigator.currentState!.canPop(), isFalse);
  });

  testWidgets('Authenticated users cannot open Login or Register', (
    tester,
  ) async {
    await tester.runAsync(
      () => auth.signIn(email: 'staff@exampler.com', password: 'staff123'),
    );
    await start(tester, AppRoutes.login);
    expect(find.byType(StaffMain), findsOneWidget);
    for (final route in [AppRoutes.register, AppRoutes.login]) {
      navigator.currentState!.pushNamed(route);
      await tester.pumpAndSettle();
      expect(find.byType(StaffMain), findsOneWidget);
      expect(find.text('Join Us'), findsNothing);
      expect(find.text('Welcome Back'), findsNothing);
      expect(navigator.currentState!.canPop(), isFalse);
    }
  });

  testWidgets('Customer cannot access staff or admin pages', (tester) async {
    await tester.runAsync(
      () => auth.signIn(email: 'customer@example.com', password: 'customer123'),
    );
    await start(tester, AppRoutes.customerHome);
    for (final route in [
      AppRoutes.managerDashboard,
      AppRoutes.managerServices,
      AppRoutes.staffSchedule,
    ]) {
      navigator.currentState!.pushNamed(route);
      await tester.pumpAndSettle();
      expect(find.text('Xin chào, Customer Demo!'), findsOneWidget);
      expect(find.byType(ManagerMain), findsNothing);
      expect(find.byType(StaffMain), findsNothing);
    }
  });

  testWidgets('Logout clears session and all protected navigation history', (
    tester,
  ) async {
    await tester.runAsync(
      () => auth.signIn(email: 'customer@example.com', password: 'customer123'),
    );
    await start(tester, AppRoutes.customerHome);
    navigator.currentState!.pushNamed(AppRoutes.services);
    await tester.pumpAndSettle();
    expect(navigator.currentState!.canPop(), isTrue);
    navigator.currentState!.pushNamed(AppRoutes.customerHome);
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.byIcon(Icons.person_outline),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(auth.currentUser, isNull);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(navigator.currentState!.canPop(), isFalse);
    await navigator.currentState!.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Welcome Back'), findsOneWidget);
  });

  testWidgets('Session changes also protect an already-open page', (
    tester,
  ) async {
    await tester.runAsync(
      () => auth.signIn(email: 'admin@example.com', password: 'admin123'),
    );
    await start(tester, AppRoutes.managerDashboard);
    auth.signOut();
    await tester.pumpAndSettle();
    expect(find.byType(ManagerMain), findsNothing);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(navigator.currentState!.canPop(), isFalse);
  });
}
