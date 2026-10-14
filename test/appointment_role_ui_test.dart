import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/models/app_user.dart';
import 'package:ktgk/core/network/api_client.dart';
import 'package:ktgk/core/network/token_store.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/api_auth_repository.dart';
import 'package:ktgk/features/booking/application/api_appointment_provider.dart';
import 'package:ktgk/features/booking/application/appointment_permissions.dart';
import 'package:ktgk/features/booking/data/api_booking_repository.dart';
import 'package:ktgk/features/booking/presentation/api_appointments_screen.dart';

import 'api_integration_test.dart' show MemoryTokens, profile, json;

ApiAppointment appointment({
  String status = 'confirmed',
  String owner = 'actor',
  String staff = 'actor',
  String branch = 'branch-real',
}) => ApiAppointment({
  'id': 'appointment',
  'customerId': owner,
  'staffId': staff,
  'branchId': branch,
  'status': status,
  'totalPriceVnd': '100000',
  'startAt': '2030-01-02T01:00:00Z',
  'endAt': '2030-01-02T01:30:00Z',
  'services': [
    {'serviceNameSnapshot': 'Cắt tóc'},
  ],
});

void main() {
  for (final role in UserRole.values) {
    test('permissions match $role, ownership, branch and transitions', () {
      final user = AppUser(
        id: 'actor',
        name: 'Actor',
        email: 'a@example.com',
        role: role,
        createdAt: DateTime.utc(2026),
        branchId: 'branch-real',
        isApproved: true,
      );
      final own = appointment();
      expect(canActOnAppointment(user, own, 'cancel'), role != UserRole.staff);
      expect(
        canActOnAppointment(user, own, 'complete'),
        role == UserRole.manager || role == UserRole.staff,
      );
      expect(
        canActOnAppointment(user, own, 'no-show'),
        role == UserRole.manager || role == UserRole.staff,
      );
      expect(
        canActOnAppointment(user, appointment(status: 'pending'), 'complete'),
        false,
      );
      expect(
        canActOnAppointment(user, appointment(status: 'completed'), 'cancel'),
        false,
      );
      expect(
        canActOnAppointment(
          user,
          appointment(status: 'noShow'),
          'hide/customer',
        ),
        role == UserRole.customer,
      );
      expect(
        canActOnAppointment(
          user,
          appointment(status: 'completed'),
          'hide/staff',
        ),
        role == UserRole.staff,
      );
      for (final action in [
        'cancel',
        'complete',
        'no-show',
        'hide/customer',
        'hide/staff',
      ]) {
        expect(
          canActOnAppointment(
            user,
            appointment(owner: 'other', staff: 'other', branch: 'other'),
            action,
          ),
          role == UserRole.superAdmin && action == 'cancel',
        );
      }
    });
  }

  for (final role in ['customer', 'staff', 'manager', 'boss']) {
    testWidgets('$role sees only its appointment actions', (tester) async {
      var mutations = 0;
      final api = ApiClient(
        tokens: TokenStore(MemoryTokens()),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return json({
              'accessToken': 't',
              'user': profile(id: 'actor', role: role),
            });
          }
          if (r.method == 'POST') mutations++;
          return json([]);
        }),
      );
      final auth = AuthController(null, apiRepository: ApiAuthRepository(api));
      await auth.signIn(email: 'a@example.com', password: 'x');
      final p = ApiAppointmentProvider(ApiBookingRepository(api), auth);
      await p.refresh();
      p.rows = [appointment()];
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: p),
          ],
          child: const MaterialApp(home: ApiAppointmentsScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.widgetWithText(TextButton, 'Khách không đến'),
        role == 'staff' || role == 'manager' ? findsOneWidget : findsNothing,
      );
      expect(
        find.widgetWithText(TextButton, 'Hoàn thành ca'),
        role == 'staff' || role == 'manager' ? findsOneWidget : findsNothing,
      );
      expect(
        find.widgetWithText(TextButton, 'Hủy lịch'),
        role == 'staff' ? findsNothing : findsOneWidget,
      );
      if (role == 'customer') {
        await expectLater(p.act('appointment', 'no-show'), throwsStateError);
        await expectLater(p.act('appointment', 'complete'), throwsStateError);
        expect(mutations, 0);
        expect(find.text('Khách không đến'), findsNothing);
        expect(find.text('Đặt lịch ngay'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      p.dispose();
      auth.dispose();
      api.close();
    });
  }
}
