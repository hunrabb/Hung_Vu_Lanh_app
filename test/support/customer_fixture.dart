import 'package:ktgk/core/models/app_user.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';

AuthController customerFixtureAuth({bool manager = false}) =>
    _FixtureSession(manager);

class _FixtureSession extends AuthController {
  _FixtureSession(bool manager)
    : _user = MockUserRepository().getById(
        manager ? 'admin-01' : 'customer-01',
      ),
      super(MockAuthRepository());
  AppUser? _user;
  @override
  AppUser? get currentUser => _user;
  @override
  void signOut() {
    _user = null;
    super.signOut();
  }
}
