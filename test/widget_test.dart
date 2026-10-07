import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktgk/app.dart';
import 'package:ktgk/core/routing/app_router.dart';
import 'package:ktgk/core/routing/app_routes.dart';
import 'package:ktgk/features/auth/domain/app_user.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('App starts at login', (tester) async {
    await tester.pumpWidget(const BarbershopApp(useMock: true));
    expect(find.text('Login'), findsOneWidget);
  });
  test('Each role has its own landing route', () {
    expect(AppRoutes.homeFor(UserRole.customer), AppRoutes.customerHome);
    expect(AppRoutes.homeFor(UserRole.staff), AppRoutes.staffSchedule);
    expect(AppRoutes.homeFor(UserRole.manager), AppRoutes.managerDashboard);
  });
  testWidgets('Unknown route shows fallback', (tester) async {
    final auth = AuthController(MockAuthRepository());
    addTearDown(auth.dispose);
    await tester.runAsync(
      () => auth.signIn(email: 'customer@example.com', password: 'customer123'),
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          initialRoute: '/missing',
          onGenerateRoute: AppRouter.generateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);
  });
}
