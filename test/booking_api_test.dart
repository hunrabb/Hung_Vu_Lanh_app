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
import 'package:ktgk/core/routing/app_routes.dart';
import 'package:ktgk/features/customer/presentation/customer_main.dart';

import 'support/booking_test_scope.dart';

import 'api_integration_test.dart' show MemoryTokens, profile, json;

void main() {
  test(
    'appointment money remains a precise string including Web-unsafe integers',
    () {
      final a = ApiAppointment({'totalPriceVnd': '9007199254740993'});
      expect(a.price, '9007199254740993');
    },
  );
  for (final scenario in ['conflict', 'success', 'refresh-failure']) {
    final conflict = scenario == 'conflict';
    testWidgets(
      conflict
          ? 'Booking 409 clears slot and refreshes availability'
          : 'API booking returns Home and customer cancels: $scenario',
      (tester) async {
        var slotsCalls = 0, posts = 0;
        Map<String, dynamic>? booked;
        var cancelled = 0;
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
                {
                  'id': 'branch-real',
                  'name': 'Cơ sở API',
                  'address': 'Hà Nội',
                  'phone': '0900000000',
                },
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
            if (r.method == 'GET' && r.url.path.endsWith('/appointments')) {
              if (scenario == 'refresh-failure' && booked != null) {
                return json({'message': 'Temporarily unavailable'}, 500);
              }
              final status = r.url.queryParameters['status'];
              return json(
                booked != null &&
                        (status == null || booked!['status'] == status)
                    ? [booked]
                    : [],
              );
            }
            if (r.method == 'POST' &&
                r.url.path.endsWith('/new-booking/cancel')) {
              cancelled++;
              booked!['status'] = 'cancelled';
              return json(booked!);
            }
            if (r.method == 'POST' && r.url.path.endsWith('/appointments')) {
              posts++;
              final body = jsonDecode(r.body) as Map;
              expect(body.containsKey('customerId'), false);
              expect(body.containsKey('totalPriceVnd'), false);
              expect(body['branchId'], 'branch-real');
              if (conflict) {
                return json({'message': 'Slot no longer available'}, 409);
              }
              booked = {
                'id': 'new-booking',
                'customerId': 'boss-real',
                'branchId': 'branch-real',
                'staffId': 'staff-real',
                'status': 'confirmed',
                'totalPriceVnd': '80000',
                'startAt': '2030-01-02T01:00:00Z',
                'endAt': '2030-01-02T01:30:00Z',
                'services': [
                  {
                    'serviceId': 'svc-real',
                    'serviceNameSnapshot': 'Dịch vụ API',
                  },
                ],
              };
              return json(booked!, 201);
            }
            return json([]);
          }),
        );
        final auth = AuthController(
          null,
          apiRepository: ApiAuthRepository(api),
        );
        await auth.signIn(email: 'customer@example.com', password: 'x');
        final p = ApiAppointmentProvider(ApiBookingRepository(api), auth);
        await tester.pumpWidget(
          BookingTestScope(
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider.value(value: auth),
                ChangeNotifierProvider.value(value: p),
              ],
              child: MaterialApp(
                routes: {AppRoutes.customerHome: (_) => const CustomerMain()},
                home: const ApiBookingScreen(initialBranchId: 'branch-real'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byType(DropdownButtonFormField<String>).at(1),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dịch vụ').first);
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Dịch vụ API').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byType(DropdownButtonFormField<String>).last,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Chọn thợ').first);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Thợ API').last);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(ChoiceChip).first);
        await tester.pumpAndSettle();
        await tester.tap(find.byType(ChoiceChip).first);
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.text('Xác nhận đặt lịch'));
        await tester.tap(find.text('Xác nhận đặt lịch'));
        await tester.pumpAndSettle();
        expect(posts, 1);
        if (conflict) {
          expect(slotsCalls, 2);
          expect(find.text(bookingConflict), findsOneWidget);
          expect(
            tester.widget<ChoiceChip>(find.byType(ChoiceChip).first).selected,
            false,
          );
        } else {
          expect(find.byType(ApiBookingScreen), findsNothing);
          expect(find.byType(CustomerMain), findsOneWidget);
          expect(find.text('Đặt lịch thành công!'), findsOneWidget);
          expect(
            tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
            isFalse,
          );
          await tester.ensureVisible(find.text('Hủy lịch'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Hủy lịch'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Đồng ý'));
          await tester.pumpAndSettle();
          expect(cancelled, 1);
          expect(p.upcoming, isEmpty);
          expect(p.rows.single.status, 'cancelled');
          expect(find.text('Hủy lịch'), findsNothing);
        }
        await tester.pumpWidget(const SizedBox());
        p.dispose();
        auth.dispose();
        api.close();
      },
    );
  }
}
