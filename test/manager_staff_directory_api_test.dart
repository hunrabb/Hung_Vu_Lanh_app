import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/network/api_client.dart';
import 'package:ktgk/core/network/token_store.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/api_auth_repository.dart';
import 'package:ktgk/features/manager/presentation/api_manager_staff_screen.dart';
import 'package:ktgk/features/workspace/application/workspace_provider.dart';
import 'package:ktgk/features/workspace/data/workspace_repository.dart';

import 'api_integration_test.dart' show MemoryTokens, profile, json;

void main() {
  testWidgets(
    'API staff directory retries errors and discards response after logout',
    (tester) async {
      var fail = true;
      Completer<http.Response>? delayed;
      final paths = <String>[];
      final api = ApiClient(
        tokens: TokenStore(MemoryTokens()),
        client: MockClient((request) async {
          paths.add(request.url.path);
          if (request.url.path.endsWith('/login')) {
            return json({
              'accessToken': 'manager-token',
              'user': profile(role: 'manager'),
            });
          }
          if (request.url.path.contains('/users/branch/')) {
            if (delayed != null) return delayed.future;
            if (fail) return json({'message': 'Directory unavailable'}, 500);
            return json([
              {
                ...profile(role: 'staff', id: 'staff-api'),
                'name': 'Nhân viên API',
                'specializedCategoryIds': ['haircut'],
              },
            ]);
          }
          return json([]);
        }),
      );
      final auth = AuthController(null, apiRepository: ApiAuthRepository(api));
      await auth.signIn(email: 'manager@example.com', password: 'x');
      final workspace = WorkspaceProvider(WorkspaceRepository(api), auth);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider.value(value: api),
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: workspace),
          ],
          child: const MaterialApp(home: ApiManagerStaffScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Directory unavailable'), findsWidgets);
      fail = false;
      await tester.ensureVisible(find.text('Thử lại'));
      await tester.tap(find.text('Thử lại'));
      await tester.pumpAndSettle();
      expect(find.text('Nhân viên API'), findsOneWidget);
      expect(paths, contains('/api/users/branch/branch-real'));
      expect(find.byIcon(Icons.delete), findsNothing);
      delayed = Completer<http.Response>();
      await tester.tap(find.byTooltip('Làm mới'));
      await tester.pump();
      auth.signOut();
      delayed.complete(
        json([
          {...profile(role: 'staff'), 'name': 'Late employee'},
        ]),
      );
      await tester.pump();
      await tester.pump();
      expect(find.text('Nhân viên API'), findsNothing);
      expect(find.text('Late employee'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      workspace.dispose();
      auth.dispose();
      api.close();
    },
  );
}
