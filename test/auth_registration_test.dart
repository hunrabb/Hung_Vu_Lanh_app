import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktgk/app.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';
import 'package:ktgk/features/auth/domain/app_user.dart';
import 'package:provider/provider.dart';

void main() {
  test('New customer can sign in and IDs are unique', () {
    final repository = MockAuthRepository();
    final user = repository.register(
      name: ' New Customer ',
      email: ' NEW@EXAMPLE.COM ',
      password: 'pass123',
    );
    expect(user.name, 'New Customer');
    expect(user.email, 'new@example.com');
    expect(user.role, UserRole.customer);
    expect(
      repository.signIn(email: 'new@example.com', password: 'pass123'),
      user,
    );
    expect(
      repository.signIn(email: 'new@example.com', password: 'wrong'),
      isNull,
    );
    final other = repository.register(
      name: 'Other',
      email: 'other@example.com',
      password: 'pass123',
    );
    expect(other.id, isNot(user.id));
  });

  test('Duplicate emails are rejected after normalization', () {
    final repository = MockAuthRepository();
    expect(
      () => repository.register(
        name: 'Duplicate',
        email: ' CUSTOMER@EXAMPLE.COM ',
        password: 'different',
      ),
      throwsA(
        isA<MockAuthException>().having(
          (error) => error.message,
          'message',
          'Email đã được sử dụng',
        ),
      ),
    );
    expect(
      repository.signIn(email: 'customer@example.com', password: 'customer123'),
      isNotNull,
    );
    repository.register(
      name: 'New',
      email: 'new@example.com',
      password: 'pass',
    );
    expect(
      () => repository.register(
        name: 'Duplicate',
        email: 'NEW@example.com',
        password: 'pass',
      ),
      throwsA(isA<MockAuthException>()),
    );
  });

  test(
    'Controller reports duplicate error and authenticates on retry',
    () async {
      final controller = AuthController(MockAuthRepository());
      addTearDown(controller.dispose);
      expect(
        await controller.register(
          name: 'Duplicate',
          email: 'admin@example.com',
          password: 'pass',
        ),
        isFalse,
      );
      expect(controller.errorMessage, 'Email đã được sử dụng');
      expect(controller.currentUser, isNull);
      expect(controller.isLoading, isFalse);
      final states = <bool>[];
      controller.addListener(() => states.add(controller.isLoading));
      final pending = controller.register(
        name: 'New',
        email: 'new@example.com',
        password: 'pass',
      );
      expect(controller.isLoading, isTrue);
      expect(controller.errorMessage, isNull);
      expect(await pending, isTrue);
      expect(states, [true, false]);
      expect(controller.currentUser?.role, UserRole.customer);
      controller.signOut();
      expect(
        await controller.signIn(email: 'new@example.com', password: 'pass'),
        isTrue,
      );
    },
  );

  test('Sign-out cancels registration before repository writes', () async {
    final repository = MockAuthRepository();
    final controller = AuthController(repository);
    addTearDown(controller.dispose);
    final pending = controller.register(
      name: 'New',
      email: 'new@example.com',
      password: 'pass',
    );
    controller.signOut();
    expect(await pending, isFalse);
    expect(
      repository.signIn(email: 'new@example.com', password: 'pass'),
      isNull,
    );
    expect(controller.currentUser, isNull);
  });

  Future<void> openRegistration(WidgetTester tester) async {
    await tester.pumpWidget(const BarbershopApp(useMock: true));
    await tester.ensureVisible(find.text("Don't have an account? Register"));
    await tester.tap(find.text("Don't have an account? Register"));
    await tester.pumpAndSettle();
  }

  Future<void> fillForm(
    WidgetTester tester,
    String email,
    String confirmation,
  ) async {
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'New Customer');
    await tester.enterText(fields.at(1), email);
    await tester.enterText(fields.at(2), 'pass123');
    await tester.enterText(fields.at(3), confirmation);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Register'));
    await tester.tap(find.widgetWithText(FilledButton, 'Register'));
  }

  testWidgets('Mismatched passwords stay on form without updating Auth', (
    tester,
  ) async {
    await openRegistration(tester);
    await fillForm(tester, 'new@example.com', 'wrong');
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu xác nhận không khớp.'), findsOneWidget);
    final auth = tester.element(find.byType(Form)).read<AuthController>();
    expect(auth.currentUser, isNull);
    expect(auth.isLoading, isFalse);
  });

  testWidgets('Duplicate registration displays SnackBar', (tester) async {
    await openRegistration(tester);
    await fillForm(tester, 'customer@example.com', 'pass123');
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Email đã được sử dụng'), findsOneWidget);
    expect(find.text('Join Us'), findsOneWidget);
  });

  testWidgets('Successful registration navigates to customer placeholder', (
    tester,
  ) async {
    await openRegistration(tester);
    await fillForm(tester, 'new@example.com', 'pass123');
    await tester.pumpAndSettle();
    expect(find.text('Xin chào, New Customer!'), findsOneWidget);
    final auth = tester.element(find.byType(Scaffold)).read<AuthController>();
    expect(auth.currentUser?.email, 'new@example.com');
    expect(auth.currentUser?.role, UserRole.customer);
  });
}
