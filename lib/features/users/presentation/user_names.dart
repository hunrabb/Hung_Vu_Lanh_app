import '../application/user_provider.dart';
import '../../../core/security/access_scope.dart';

/// UI fallback for historical records whose referenced profile is no longer visible.
String visibleUserName(UserProvider provider, String id, String fallback) {
  try {
    return provider.getById(id)?.name ?? fallback;
  } on UnauthorizedException {
    return fallback;
  }
}
