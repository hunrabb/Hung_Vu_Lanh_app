import 'package:flutter_test/flutter_test.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';
import 'package:ktgk/features/auth/domain/app_user.dart';

class _FailingRepository extends MockAuthRepository {
  @override
  AppUser? signIn({required String email, required String password}) {
    throw StateError('Mock failure');
  }
}

void main() {
  late AuthController controller;

  setUp(() {
    controller = AuthController(MockAuthRepository());
  });
  tearDown(() => controller.dispose());

  test('Starts signed out without loading or error', () {
    expect(controller.currentUser, isNull);
    expect(controller.isAuthenticated, isFalse);
    expect(controller.isLoading, isFalse);
    expect(controller.errorMessage, isNull);
  });

  test('Reports loading then authenticates each sample role', () async {
    for (final role in UserRole.values) {
      final loadingStates = <bool>[];
      void listener() => loadingStates.add(controller.isLoading);
      controller.addListener(listener);
      final pending = controller.signIn(
        email: switch (role) {
          UserRole.superAdmin => ' BOSS@EXAMPLE.COM ',
          UserRole.manager => ' ADMIN@EXAMPLE.COM ',
          UserRole.staff => ' STAFF@EXAMPLER.COM ',
          UserRole.customer => ' CUSTOMER@EXAMPLE.COM ',
        },
        password: switch (role) {
          UserRole.superAdmin => 'boss123',
          UserRole.manager => 'admin123',
          UserRole.staff => 'staff123',
          UserRole.customer => 'customer123',
        },
      );
      expect(controller.isLoading, isTrue);
      expect(await pending, isTrue);
      expect(controller.currentUser?.role, role);
      expect(controller.isAuthenticated, isTrue);
      expect(loadingStates, [true, false]);
      controller.removeListener(listener);
      controller.signOut();
    }
  });

  test('Rejects incorrect credentials and clears error on retry', () async {
    expect(
      await controller.signIn(
        email: 'customer@example.com',
        password: 'CUSTOMER123',
      ),
      isFalse,
    );
    expect(controller.currentUser, isNull);
    expect(controller.errorMessage, isNotNull);
    expect(controller.isLoading, isFalse);
    expect(
      await controller.signIn(
        email: 'customer@example.com',
        password: 'customer123',
      ),
      isTrue,
    );
    expect(controller.errorMessage, isNull);
    controller.signOut();
    expect(controller.isAuthenticated, isFalse);
    expect(controller.errorMessage, isNull);
  });

  test(
    'Rejects duplicate requests and sign-out cancels pending login',
    () async {
      final pending = controller.signIn(
        email: 'customer@example.com',
        password: 'customer123',
      );
      expect(
        await controller.signIn(
          email: 'admin@example.com',
          password: 'admin123',
        ),
        isFalse,
      );
      controller.signOut();
      expect(await pending, isFalse);
      expect(controller.currentUser, isNull);
      expect(controller.isLoading, isFalse);
    },
  );

  test(
    'Repository exceptions stop loading and expose a friendly error',
    () async {
      final failing = AuthController(_FailingRepository());
      addTearDown(failing.dispose);
      expect(await failing.signIn(email: 'x', password: 'x'), isFalse);
      expect(failing.isLoading, isFalse);
      expect(failing.currentUser, isNull);
      expect(failing.errorMessage, isNotNull);
    },
  );

  test('Pending login safely finishes after disposal', () async {
    final temporary = AuthController(MockAuthRepository());
    final pending = temporary.signIn(
      email: 'customer@example.com',
      password: 'customer123',
    );
    temporary.dispose();
    expect(await pending, isFalse);
  });
}
