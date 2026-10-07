import '../../../core/models/app_user.dart';
import '../../../core/network/api_client.dart';

class ApiAuthSession {
  const ApiAuthSession(this.user, this.accessToken);
  final AppUser user;
  final String accessToken;
  factory ApiAuthSession.fromJson(dynamic json) {
    final map = Map<String, dynamic>.from(json as Map);
    final token = map['accessToken'];
    if (token is! String || token.isEmpty) {
      throw const FormatException('Missing accessToken');
    }
    return ApiAuthSession(
      AppUser.fromJson(Map<String, dynamic>.from(map['user'] as Map)),
      token,
    );
  }
}

class ApiAuthRepository {
  ApiAuthRepository(this.client);
  final ApiClient client;
  Future<void> _logoutBarrier = Future.value();
  Future<ApiAuthSession> login({
    required String email,
    required String password,
  }) async {
    await _logoutBarrier;
    await client.tokens.clear();
    return ApiAuthSession.fromJson(
      await client.request(
        'POST',
        'auth/login',
        authenticated: false,
        body: {'email': email.trim().toLowerCase(), 'password': password},
      ),
    );
  }

  Future<ApiAuthSession> register({
    required String name,
    required String email,
    required String password,
  }) async {
    await _logoutBarrier;
    await client.tokens.clear();
    return ApiAuthSession.fromJson(
      await client.request(
        'POST',
        'auth/register',
        authenticated: false,
        body: {
          'name': name.trim(),
          'email': email.trim().toLowerCase(),
          'password': password,
        },
      ),
    );
  }

  Future<AppUser?> restore() async {
    if (await client.tokens.read() == null) return null;
    return AppUser.fromJson(
      Map<String, dynamic>.from(await client.request('GET', 'auth/me') as Map),
    );
  }

  Future<int> commit(ApiAuthSession session, bool Function() isCurrent) =>
      client.tokens.write(session.accessToken, isCurrent: isCurrent);
  Future<void> logout({bool revoke = true}) {
    final oldToken = revoke
        ? client.tokens.read().catchError((Object _) => null)
        : Future<String?>.value(null);
    final cleared = client.tokens.clear();
    return _logoutBarrier = () async {
      // Local session clears first, even if server is unavailable.
      try {
        await cleared;
      } catch (_) {}
      if (revoke) {
        try {
          final token = await oldToken;
          if (token != null) {
            await client.request(
              'POST',
              'auth/logout',
              authenticated: false,
              tokenOverride: token,
            );
          }
        } catch (_) {}
      }
    }();
  }
}
