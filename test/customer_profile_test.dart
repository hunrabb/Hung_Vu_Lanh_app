import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/network/api_client.dart';
import 'package:ktgk/core/network/token_store.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/api_auth_repository.dart';
import 'package:ktgk/features/customer/presentation/customer_profile_dialog.dart';

import 'api_integration_test.dart' show MemoryTokens, profile, json;

void main() {
  testWidgets('customer saves profile to PATCH API and dialog closes', (
    tester,
  ) async {
    final user = profile(id: 'customer', role: 'customer');
    Map<String, dynamic>? saved;
    final api = ApiClient(
      tokens: TokenStore(MemoryTokens()),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) {
          return json({'accessToken': 't', 'user': user});
        }
        expect(r.method, 'PATCH');
        expect(r.url.path, '/api/auth/me');
        saved = jsonDecode(r.body) as Map<String, dynamic>;
        return json({...user, ...saved!});
      }),
    );
    final auth = AuthController(null, apiRepository: ApiAuthRepository(api));
    await auth.signIn(email: 'c@example.com', password: 'x');
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(
          home: Builder(
            builder: (c) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: c,
                  builder: (_) =>
                      CustomerProfileDialog(user: auth.currentUser!),
                ),
                child: const Text('Edit'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Tên mới');
    await tester.enterText(find.byType(TextFormField).at(3), 'Hà Nội');
    await tester.tap(find.text('Lưu hồ sơ'));
    await tester.pumpAndSettle();
    expect(saved?['name'], 'Tên mới');
    expect(auth.currentUser?.address, 'Hà Nội');
    expect(find.byType(CustomerProfileDialog), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });
  test('late profile response cannot restore signed-out session', () async {
    final pending = Completer<http.Response>();
    final started = Completer<void>();
    final user = profile(id: 'customer', role: 'customer');
    final api = ApiClient(
      tokens: TokenStore(MemoryTokens()),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) {
          return json({'accessToken': 't', 'user': user});
        }
        if (r.method == 'PATCH') {
          started.complete();
          return pending.future;
        }
        return json({});
      }),
    );
    final auth = AuthController(null, apiRepository: ApiAuthRepository(api));
    await auth.signIn(email: 'c@example.com', password: 'x');
    final saving = auth.updateOwnProfile(
      name: 'New',
      email: 'c@example.com',
      phone: '',
      address: '',
    );
    await started.future;
    auth.signOut();
    pending.complete(json({...user, 'name': 'New'}));
    expect(await saving, false);
    expect(auth.currentUser, isNull);
    auth.dispose();
  });
}
