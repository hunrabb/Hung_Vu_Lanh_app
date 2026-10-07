import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:ktgk/core/network/api_client.dart';
import 'package:ktgk/core/network/token_store.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/api_auth_repository.dart';
import 'package:ktgk/features/workspace/application/workspace_provider.dart';
import 'package:ktgk/features/workspace/data/workspace_repository.dart';
import 'package:ktgk/features/workspace/presentation/workspace_screen.dart';
import 'package:provider/provider.dart';

import 'api_integration_test.dart' show MemoryTokens, profile, json;

void main() {
  test('Hanoi form timestamps do not depend on device timezone', () {
    expect(
      hanoiInstant(
        DateTime(2030, 1, 2),
        const TimeOfDay(hour: 8, minute: 30),
      ).toIso8601String(),
      '2030-01-02T01:30:00.000Z',
    );
  });
  testWidgets(
    'Manager shift deletion 409 shows specific Snackbar and refreshes; logout clears data',
    (tester) async {
      var gets = 0;
      final shift = {
        'id': 'shift-api',
        'staffId': 'staff-api',
        'branchId': 'branch-real',
        'startAt': '2030-01-02T01:00:00Z',
        'endAt': '2030-01-02T10:00:00Z',
      };
      final api = ApiClient(
        tokens: TokenStore(MemoryTokens()),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return json({'accessToken': 't', 'user': profile(role: 'manager')});
          }
          if (r.method == 'DELETE') {
            return json({'message': 'Shift has booked appointments'}, 409);
          }
          if (r.url.path.endsWith('/branches')) {
            return json([
              {'id': 'branch-real', 'name': 'Cơ sở API'},
            ]);
          }
          if (r.url.path.endsWith('/shifts')) {
            gets++;
            return json([shift]);
          }
          if (r.url.path.endsWith('/leave-requests')) return json([]);
          if (r.url.path.contains('/users/branch/')) {
            return json([
              profile(id: 'staff-api', role: 'staff')..['name'] = 'Staff API',
            ]);
          }
          return json({'message': 'ok'});
        }),
      );
      final auth = AuthController(null, apiRepository: ApiAuthRepository(api));
      await auth.signIn(email: 'manager@example.com', password: 'x');
      final workspace = WorkspaceProvider(WorkspaceRepository(api), auth);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: workspace),
          ],
          child: const MaterialApp(home: WorkspaceScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Staff API'), findsOneWidget);
      await tester.tap(find.text('Xóa ca'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Không thể xóa ca: ca đã có lịch khách hoặc dữ liệu đang xung đột.',
        ),
        findsOneWidget,
      );
      expect(gets, greaterThan(1));
      expect(workspace.shifts.single.id, 'shift-api');
      auth.signOut();
      expect(workspace.shifts, isEmpty);
      expect(workspace.leaves, isEmpty);
      await tester.pumpWidget(const SizedBox());
      workspace.dispose();
      auth.dispose();
      api.close();
    },
  );
}
