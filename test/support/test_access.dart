import 'package:ktgk/core/security/access_scope.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';

// Explicit trusted session for existing domain/UI fixtures; production defaults deny writes.
final _boss = MockUserRepository().getById('boss-01')!;
AccessScope testAccess() => AccessScope(() => _boss);
