import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/network/api_client.dart';
import 'package:ktgk/core/network/token_store.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/api_auth_repository.dart';
import 'package:ktgk/features/booking/application/api_appointment_provider.dart';
import 'package:ktgk/features/booking/data/api_booking_repository.dart';
import 'package:ktgk/features/booking/presentation/api_booking_screen.dart';

import 'api_integration_test.dart' show MemoryTokens, profile, json;

void main() {
  test(
    'appointment money remains a precise string including Web-unsafe integers',
    () {
      final a = ApiAppointment({'totalPriceVnd': '9007199254740993'});
      expect(a.price, '9007199254740993');
    },
  );
  testWidgets(
    'Booking uses server staff/slots; 409 Snackbar clears slot and refreshes availability',
    (tester) async {
      var slotsCalls = 0, posts = 0;
      final api = ApiClient(
        tokens: TokenStore(MemoryTokens()),
        client: MockClient((r) async {
          if (r.url.path.endsWith('/login')) {
            return json({
              'accessToken': 't',
              'user': profile(role: 'customer'),
            });
          }
          if (r.url.path.endsWith('/branches')) {
            return json([
              {'id': 'branch-real', 'name': 'Cơ sở API'},
            ]);
          }
          if (r.url.path.endsWith('/services')) {
            return json([
              {
                'id': 'svc-real',
                'name': 'Dịch vụ API',
                'price': '80000',
                'duration': 30,
                'isActive': true,
              },
            ]);
          }
          if (r.url.path.endsWith('/staff')) {
            return json([
              {'id': 'staff-real', 'name': 'Thợ API'},
            ]);
          }
          if (r.url.path.endsWith('/available-slots')) {
            slotsCalls++;
            return json({
              'slots': [
                {
                  'startAt': '2030-01-02T01:00:00Z',
                  'endAt': '2030-01-02T01:30:00Z',
                },
              ],
            });
          }
          if (r.method == 'POST' && r.url.path.endsWith('/appointments')) {
            posts++;
            final body = jsonDecode(r.body) as Map;
            expect(body.containsKey('customerId'), false);
            expect(body.containsKey('totalPriceVnd'), false);
            expect(body['branchId'], 'branch-real');
            return json({'message': 'Slot no longer available'}, 409);
          }
          return json([]);
        }),
      );
      final auth = AuthController(null, apiRepository: ApiAuthRepository(api));
      await auth.signIn(email: 'customer@example.com', password: 'x');
      final p = ApiAppointmentProvider(ApiBookingRepository(api), auth);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: p),
          ],
          child: const MaterialApp(
            home: ApiBookingScreen(initialBranchId: 'branch-real'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dịch vụ').first);
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Dịch vụ API').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chọn thợ').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thợ API').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ChoiceChip).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Xác nhận đặt lịch'));
      await tester.tap(find.text('Xác nhận đặt lịch'));
      await tester.pumpAndSettle();
      expect(posts, 1);
      expect(slotsCalls, 2);
      expect(find.text(bookingConflict), findsOneWidget);
      expect(
        tester.widget<ChoiceChip>(find.byType(ChoiceChip).first).selected,
        false,
      );
      await tester.pumpWidget(const SizedBox());
      p.dispose();
      auth.dispose();
      api.close();
    },
  );
}
