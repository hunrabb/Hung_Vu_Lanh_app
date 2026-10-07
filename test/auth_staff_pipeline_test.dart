import 'support/test_access.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ktgk/core/models/app_user.dart';
import 'package:ktgk/core/routing/app_routes.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';
import 'package:ktgk/features/users/application/user_provider.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';

void main() {
  test(
    'Admin creation uses Login repository even with an isolated UserProvider',
    () async {
      final loginUsers = MockUserRepository();
      final loginRepository = MockAuthRepository(users: loginUsers);
      final auth = AuthController(loginRepository);
      final profiles = UserProvider(
        MockUserRepository(initialData: []),
        access: testAccess(),
      );
      addTearDown(auth.dispose);
      addTearDown(profiles.dispose);
      await auth.signIn(email: 'boss@example.com', password: 'boss123');
      final user = auth.createStaffAccount(
        branchId: 'branch-01',
        email: ' NEWSTAFF@EXAMPLE.COM ',
        password: 'staffPassword',
        name: ' New Staff ',
        specializedCategoryIds: ['haircut'],
        users: profiles,
      );
      expect(auth.currentUser?.role, UserRole.superAdmin);
      expect(profiles.getById(user.id)?.email, 'newstaff@example.com');
      expect(loginUsers.getById(user.id)?.role, UserRole.staff);
      expect(
        () => auth.createStaffAccount(
          branchId: 'branch-01',
          email: user.email,
          password: 'other',
          name: 'Duplicate',
          users: profiles,
        ),
        throwsStateError,
      );
      expect(profiles.users, hasLength(1));
      auth.signOut();
      expect(
        await auth.signIn(email: 'NEWSTAFF@example.com', password: 'wrong'),
        isFalse,
      );
      expect(
        await auth.signIn(
          email: 'NEWSTAFF@example.com',
          password: 'staffPassword',
        ),
        isTrue,
      );
      expect(auth.currentUser?.id, user.id);
      expect(
        AppRoutes.homeFor(auth.currentUser!.role),
        AppRoutes.staffSchedule,
      );
      profiles.update(user.copyWith(email: 'edited@example.com'));
      expect(
        () => profiles.update(user.copyWith(email: 'linh@example.com')),
        throwsStateError,
      );
      expect(profiles.getById(user.id)?.email, 'edited@example.com');
      expect(loginUsers.getById(user.id)?.email, 'edited@example.com');
      auth.signOut();
      expect(
        await auth.signIn(
          email: 'edited@example.com',
          password: 'staffPassword',
        ),
        isTrue,
      );
      auth.signOut();
      profiles.delete(user.id);
      expect(loginUsers.getById(user.id), isNull);
      expect(
        await auth.signIn(
          email: 'edited@example.com',
          password: 'staffPassword',
        ),
        isFalse,
      );
    },
  );

  test(
    'Signed-out and Customer sessions cannot create internal accounts',
    () async {
      final auth = AuthController(MockAuthRepository());
      final profiles = UserProvider(
        MockUserRepository(initialData: []),
        access: testAccess(),
      );
      addTearDown(auth.dispose);
      addTearDown(profiles.dispose);
      void create() => auth.createStaffAccount(
        branchId: 'branch-01',
        email: 's@example.com',
        password: 'pass',
        name: 'Staff',
        users: profiles,
      );
      expect(create, throwsStateError);
      await auth.signIn(email: 'customer@example.com', password: 'customer123');
      expect(create, throwsStateError);
      expect(profiles.users, isEmpty);
    },
  );
}
