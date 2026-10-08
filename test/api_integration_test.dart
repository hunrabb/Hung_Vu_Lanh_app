import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:ktgk/app.dart';
import 'package:ktgk/core/models/app_user.dart';
import 'package:ktgk/core/network/api_client.dart';
import 'package:ktgk/core/network/api_config.dart';
import 'package:ktgk/core/network/api_money.dart';
import 'package:ktgk/core/network/token_store.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/api_auth_repository.dart';
import 'package:ktgk/features/boss/application/pending_staff_provider.dart';
import 'package:ktgk/features/boss/data/api_pending_staff_repository.dart';

class MemoryTokens implements TokenPersistence {
  String? value;
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String value) async {
    this.value = value;
  }

  @override
  Future<void> clear() async {
    value = null;
  }
}

class SlowTokens extends MemoryTokens {
  final started = Completer<void>(), release = Completer<void>();
  @override
  Future<void> write(String value) async {
    started.complete();
    await release.future;
    await super.write(value);
  }
}

Map<String, dynamic> profile({
  String id = 'boss-real',
  String role = 'boss',
  bool approved = true,
}) => {
  'id': id,
  'role': role,
  'name': 'Boss API',
  'email': 'boss@example.com',
  'branchId': role == 'staff' || role == 'manager' ? 'branch-real' : null,
  'isApproved': approved,
  'createdAt': '2026-10-07T00:00:00Z',
};
http.Response json(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
void main() {
  test(
    'stale cleanup cannot clear a newer session with an identical JWT string',
    () async {
      final tokens = TokenStore(MemoryTokens());
      final old = await tokens.write('same-jwt', isCurrent: () => true);
      await tokens.write('same-jwt', isCurrent: () => true);
      await tokens.clearIf('same-jwt', expectedRevision: old);
      expect(await tokens.read(), 'same-jwt');
    },
  );
  test('dispose during storage write clears the canceled token', () async {
    final storage = SlowTokens(), tokens = TokenStore(storage);
    final api = ApiClient(
      tokens: tokens,
      client: MockClient(
        (_) async =>
            json({'accessToken': 'cancelled-write', 'user': profile()}),
      ),
    );
    final auth = AuthController(null, apiRepository: ApiAuthRepository(api));
    final login = auth.signIn(email: 'boss@example.com', password: 'x');
    await storage.started.future;
    auth.dispose();
    storage.release.complete();
    expect(await login, false);
    expect(await tokens.read(), null);
    api.close();
  });
  test('base URLs and exact money strings are platform safe', () {
    expect(
      ApiConfig.defaultBaseUrl(isWeb: false, platform: TargetPlatform.android),
      'http://10.0.2.2:3000/api',
    );
    expect(
      ApiConfig.defaultBaseUrl(isWeb: true, platform: TargetPlatform.android),
      'http://localhost:3000/api',
    );
    expect(
      ApiMoney.bigInt('9007199254740993'),
      BigInt.parse('9007199254740993'),
    );
    expect(() => ApiMoney.safeInt('9007199254740993'), throwsFormatException);
    expect(ApiMoney.safeInt('80000'), 80000);
    for (final role in ['boss', 'superAdmin', 'manager', 'staff', 'customer']) {
      expect(
        AppUser.fromJson(profile(role: role)).role,
        role == 'boss' ? UserRole.superAdmin : UserRole.values.byName(role),
      );
    }
  });
  test(
    'runtime API detection distinguishes Android device and emulator',
    () async {
      await ApiConfig.initialize(
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
        androidPhysicalDeviceResolver: () async => true,
      );
      expect(ApiConfig.baseUrl, 'http://localhost:3000/api');

      await ApiConfig.initialize(
        isWebOverride: false,
        platformOverride: TargetPlatform.android,
        androidPhysicalDeviceResolver: () async => false,
      );
      expect(ApiConfig.baseUrl, 'http://10.0.2.2:3000/api');

      await ApiConfig.initialize(
        isWebOverride: true,
        platformOverride: TargetPlatform.android,
      );
      expect(ApiConfig.baseUrl, 'http://localhost:3000/api');
    },
  );
  test('login persists token, sends Bearer, restores with me, wrong password does not expire a session', () async {
    final memory = MemoryTokens(), tokens = TokenStore(memory);
    var wrong = false;
    var seenBearer = false;
    final api = ApiClient(
      tokens: tokens,
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) {
          return wrong
              ? json({'message': 'Unauthorized'}, 401)
              : json({'accessToken': 'token-real', 'user': profile()});
        }
        seenBearer = r.headers['authorization'] == 'Bearer token-real';
        return json(profile());
      }),
    );
    final auth = AuthController(null, apiRepository: ApiAuthRepository(api));
    addTearDown(auth.dispose);
    addTearDown(api.close);
    expect(
      await auth.signIn(email: 'BOSS@example.com', password: 'boss123'),
      true,
    );
    expect(memory.value, 'token-real');
    expect(auth.currentUser!.role, UserRole.superAdmin);
    final restored = AuthController(
      null,
      apiRepository: ApiAuthRepository(api),
    );
    await restored.restoreSession();
    expect(restored.currentUser!.id, 'boss-real');
    expect(seenBearer, true);
    restored.dispose();
    wrong = true;
    expect(
      await auth.signIn(email: 'boss@example.com', password: 'bad'),
      false,
    );
    expect(auth.errorMessage, contains('không đúng'));
    expect(auth.isLoading, false);
  });
  test(
    '401 clears current session, late 401 cannot expire a newer login',
    () async {
      final tokens = TokenStore(MemoryTokens());
      final old = Completer<http.Response>();
      final sent = Completer<void>();
      var token = 'old';
      final api = ApiClient(
        tokens: tokens,
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return json({'accessToken': token, 'user': profile()});
          }
          if (r.url.path.endsWith('/delayed')) {
            sent.complete();
            return old.future;
          }
          return json({'message': 'expired'}, 401);
        }),
      );
      final auth = AuthController(null, apiRepository: ApiAuthRepository(api));
      addTearDown(auth.dispose);
      addTearDown(api.close);
      await auth.signIn(email: 'boss@example.com', password: 'x');
      final request = api.request('GET', 'delayed');
      await sent.future;
      token = 'new';
      await auth.signIn(email: 'boss@example.com', password: 'x');
      old.complete(json({'message': 'expired'}, 401));
      await expectLater(request, throwsA(isA<ApiException>()));
      expect(auth.isAuthenticated, true);
      expect(await tokens.read(), 'new');
      await expectLater(
        api.request('GET', 'protected'),
        throwsA(isA<ApiException>()),
      );
      expect(auth.currentUser, null);
      expect(await tokens.read(), null);
    },
  );
  test('logout during login never persists the delayed token', () async {
    final reply = Completer<http.Response>(), sent = Completer<void>();
    final tokens = TokenStore(MemoryTokens());
    final api = ApiClient(
      tokens: tokens,
      client: MockClient((r) async {
        sent.complete();
        return reply.future;
      }),
    );
    final auth = AuthController(null, apiRepository: ApiAuthRepository(api));
    addTearDown(auth.dispose);
    addTearDown(api.close);
    final login = auth.signIn(email: 'boss@example.com', password: 'x');
    await sent.future;
    auth.signOut();
    reply.complete(json({'accessToken': 'cancelled', 'user': profile()}));
    expect(await login, false);
    expect(await tokens.read(), null);
    expect(auth.currentUser, null);
  });
  test(
    'pending fetch and approve409 refresh use API only; logout clears rows',
    () async {
      var fetches = 0;
      final api = ApiClient(
        tokens: TokenStore(MemoryTokens()),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return json({'accessToken': 'token', 'user': profile()});
          }
          if (r.url.path.endsWith('/pending')) {
            fetches++;
            return json(
              fetches == 1
                  ? [
                      profile(
                        id: 'pending-real',
                        role: 'staff',
                        approved: false,
                      ),
                    ]
                  : [],
            );
          }
          if (r.url.path.endsWith('/branches')) {
            return json([
              {'id': 'branch-real', 'name': 'Cơ sở Hà Nội'},
            ]);
          }
          if (r.url.path.endsWith('/approve')) {
            return json({'message': 'already approved'}, 409);
          }
          return json({'message': 'ok'});
        }),
      );
      final auth = AuthController(null, apiRepository: ApiAuthRepository(api));
      await auth.signIn(email: 'boss@example.com', password: 'x');
      final pending = PendingStaffProvider(
        ApiPendingStaffRepository(api),
        auth,
      );
      addTearDown(pending.dispose);
      addTearDown(auth.dispose);
      addTearDown(api.close);
      await Future<void>.delayed(Duration.zero);
      while (pending.isLoading) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(pending.rows.single.id, 'pending-real');
      expect(pending.branchNames['branch-real'], 'Cơ sở Hà Nội');
      await expectLater(
        pending.decide('pending-real', password: 'Password123'),
        throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
      );
      expect(pending.rows, isEmpty);
      expect(fetches, 2);
      expect(pending.isBusy('pending-real'), false);
      auth.signOut();
      expect(pending.rows, isEmpty);
    },
  );
  testWidgets(
    'production wiring logs in and approves a real-source row; 401 dismisses dialog and returns Login',
    (tester) async {
      var approved = false, expire = false;
      final api = ApiClient(
        tokens: TokenStore(MemoryTokens()),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return json({'accessToken': 'token', 'user': profile()});
          }
          if (r.url.path.endsWith('/pending')) {
            return expire
                ? json({'message': 'expired'}, 401)
                : json(
                    approved
                        ? []
                        : [
                            profile(
                              id: 'pending-api-only',
                              role: 'staff',
                              approved: false,
                            )..['name'] = 'API Staff',
                          ],
                  );
          }
          if (r.url.path.endsWith('/branches')) {
            return json([
              {'id': 'branch-real', 'name': 'Cơ sở API'},
            ]);
          }
          if (r.url.path.endsWith('/approve')) {
            expect(jsonDecode(r.body)['password'], 'Password123');
            approved = true;
            return json(profile(id: 'pending-api-only', role: 'staff'));
          }
          return json({'message': 'ok'});
        }),
      );
      await tester.pumpWidget(BarbershopApp(networkClient: api));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'boss@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'boss123');
      await tester.tap(find.text('Login'));
      await tester.pumpAndSettle();
      expect(find.text('Boss Dashboard'), findsOneWidget);
      await tester.tap(find.text('Phê duyệt'));
      await tester.pumpAndSettle();
      expect(find.text('API Staff'), findsOneWidget);
      expect(find.text('Cơ sở API'), findsOneWidget);
      await tester.tap(find.text('Duyệt').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), 'Password123');
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.widgetWithText(FilledButton, 'Duyệt'),
        ),
      );
      await tester.pumpAndSettle();
      expect(approved, true);
      expect(find.text('API Staff'), findsNothing);
      unawaited(
        showDialog<void>(
          context: tester.element(find.text('Boss Dashboard')),
          builder: (_) => const AlertDialog(title: Text('Open modal')),
        ),
      );
      await tester.pumpAndSettle();
      expire = true;
      await expectLater(
        api.request('GET', 'users/pending'),
        throwsA(isA<ApiException>()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Login'), findsOneWidget);
      expect(find.text('Open modal'), findsNothing);
    },
  );
}
