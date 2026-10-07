import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/network/api_client.dart';
import 'package:ktgk/core/network/api_money.dart';
import 'package:ktgk/core/network/token_store.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/api_auth_repository.dart';
import 'package:ktgk/features/booking/application/api_appointment_provider.dart';
import 'package:ktgk/features/booking/data/api_booking_repository.dart';
import 'package:ktgk/features/reports/application/report_provider.dart';
import 'package:ktgk/features/reports/data/report_repository.dart';
import 'package:ktgk/features/reports/presentation/api_report_screen.dart';

import 'api_integration_test.dart' show MemoryTokens, profile, json;

void main() {
  test(
    'VND formatting is exact beyond safe integer and has comma thousands',
    () {
      expect(ApiMoney.formatVnd('1500000'), '1,500,000 VND');
      expect(
        ApiMoney.formatVnd('9007199254740993'),
        '9,007,199,254,740,993 VND',
      );
    },
  );
  testWidgets(
    'Boss dashboard API branch filter, error/retry and mutation invalidation',
    (tester) async {
      var failed = false, calls = 0;
      final queries = <String?>[];
      final api = ApiClient(
        tokens: TokenStore(MemoryTokens()),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return json({'accessToken': 't', 'user': profile()});
          }
          if (r.url.path.endsWith('/branches')) {
            return json([
              {'id': 'branch-real', 'name': 'Cơ sở API'},
            ]);
          }
          if (r.url.path.endsWith('/dashboard')) {
            calls++;
            queries.add(r.url.queryParameters['branchId']);
            if (failed) return json({'message': 'Reports unavailable'}, 500);
            return json({
              'today': {
                'revenueVnd': '1500000',
                'appointmentCount': 4,
                'cancelledCount': 1,
              },
              'month': {'revenueVnd': '9007199254740993', 'completedCount': 8},
              'upcoming': [],
            });
          }
          if (r.url.path.endsWith('/leaderboards')) {
            return json({'branches': [], 'staff': []});
          }
          return json([]);
        }),
      );
      final auth = AuthController(null, apiRepository: ApiAuthRepository(api));
      await auth.signIn(email: 'boss@example.com', password: 'x');
      final appointments = ApiAppointmentProvider(
        ApiBookingRepository(api),
        auth,
      );
      final p = ReportProvider(ReportRepository(api), auth, appointments);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: p),
          ],
          child: const MaterialApp(
            home: ApiReportScreen(kind: ReportKind.bossDashboard),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('1,500,000 VND'), findsOneWidget);
      expect(find.text('9,007,199,254,740,993 VND'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cơ sở API').last);
      await tester.pumpAndSettle();
      expect(queries.last, 'branch-real');
      failed = true;
      await tester.tap(find.text('Cập nhật'));
      await tester.pumpAndSettle();
      expect(find.text('Reports unavailable'), findsWidgets);
      failed = false;
      await tester.tap(find.text('Thử lại').first);
      await tester.pumpAndSettle();
      expect(find.text('1,500,000 VND'), findsOneWidget);
      final before = calls;
      p.appointments.recordMutation();
      await tester.pumpAndSettle();
      expect(calls, greaterThan(before));
      auth.signOut();
      expect(p.state('boss/dashboard', {}).data, isNull);
      await tester.pumpWidget(const SizedBox());
      p.dispose();
      appointments.dispose();
      auth.dispose();
      api.close();
    },
  );
}
