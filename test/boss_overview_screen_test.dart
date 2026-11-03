import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/network/api_client.dart';
import 'package:ktgk/core/network/token_store.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/api_auth_repository.dart';
import 'package:ktgk/features/boss/presentation/boss_overview_screen.dart';
import 'package:ktgk/features/booking/application/api_appointment_provider.dart';
import 'package:ktgk/features/booking/data/api_booking_repository.dart';
import 'package:ktgk/features/reports/application/report_provider.dart';
import 'package:ktgk/features/reports/data/report_repository.dart';

import 'api_integration_test.dart' show MemoryTokens, profile, json;

/// Shapes mirror `ReportsService.dashboard` / `leaderboards` on the backend.
Map<String, dynamic> dashboardJson({
  String monthRevenue = '18450000',
  String? previousRevenue = '42300000',
  List<Map<String, dynamic>>? upcoming,
}) => {
  'branchId': null,
  'timezone': 'Asia/Ho_Chi_Minh',
  'periods': {
    'day': {
      'from': '2026-10-30T17:00:00.000Z',
      'to': '2026-10-31T17:00:00.000Z',
    },
    'month': {
      'from': '2026-09-30T17:00:00.000Z',
      'to': '2026-10-31T17:00:00.000Z',
    },
  },
  'today': {
    'revenueVnd': '1500000',
    'appointmentCount': 6,
    'completedCount': 3,
    'cancelledCount': 1,
    'customerCount': 2,
    'walkInCount': 1,
  },
  'month': {
    'revenueVnd': monthRevenue,
    'appointmentCount': 62,
    'completedCount': 48,
    'cancelledCount': 5,
    'customerCount': 31,
    'walkInCount': 9,
  },
  'previousMonth': ?(previousRevenue == null
      ? null
      : {
          'revenueVnd': previousRevenue,
          'appointmentCount': 140,
          'completedCount': 121,
          'cancelledCount': 9,
          'customerCount': 77,
          'walkInCount': 22,
        }),
  'upcoming': upcoming ?? [for (var i = 0; i < 8; i++) appointmentJson(i)],
};

Map<String, dynamic> appointmentJson(int i) => {
  'id': 'a$i',
  'branchId': 'branch-01',
  'branchName': 'Cơ sở Cầu Giấy',
  'staffId': 'staff-01',
  'staffName': 'Nguyễn Minh Hùng',
  'customerId': 'c$i',
  'customerName': 'Khách số $i',
  'startAt': '2026-10-31T${(10 + i).toString().padLeft(2, '0')}:00:00.000Z',
  'endAt': '2026-10-31T${(10 + i).toString().padLeft(2, '0')}:30:00.000Z',
  'status': i.isEven ? 'confirmed' : 'pending',
  'totalPriceVnd': '${80000 + i * 10000}',
  'services': [
    {'serviceId': 's1', 'name': 'Cắt tóc nam'},
    {'serviceId': 's2', 'name': 'Gội đầu thư giãn'},
  ],
};

Map<String, dynamic> leaderboardsJson() => {
  'branches': [
    for (var i = 0; i < 4; i++)
      {
        'branchId': 'branch-0${i + 1}',
        'branchName': ['Cơ sở Cầu Giấy', 'Cơ sở Đống Đa', 'Cơ sở Hà Đông', 'Cơ sở Hai Bà Trưng'][i],
        'revenueVnd': '${(9 - i * 2) * 1000000}',
        'completedCount': 30 - i * 6,
      },
  ],
  'staff': [
    for (var i = 0; i < 7; i++)
      {
        'staffId': 'staff-0${i + 1}',
        'staffName': 'Nhân viên số ${i + 1}',
        'branches': [
          {'branchId': 'branch-01', 'branchName': 'Cơ sở Cầu Giấy'},
        ],
        'revenueVnd': '${(8 - i) * 500000}',
        'completedCount': 20 - i * 2,
      },
  ],
};

class _Harness {
  _Harness(this.handler);
  final http.Response? Function(http.Request) handler;
  final queries = <String?>[];
  int dashboardCalls = 0;
  late final ApiClient api;
  late final AuthController auth;
  late final ApiAppointmentProvider appointments;
  late final ReportProvider reports;

  Future<void> start() async {
    api = ApiClient(
      tokens: TokenStore(MemoryTokens()),
      client: MockClient((r) async {
        if (r.url.path.endsWith('/login')) {
          return json({'accessToken': 't', 'user': profile()});
        }
        if (r.url.path.endsWith('/branches')) {
          return json([
            {'id': 'branch-01', 'name': 'Cơ sở Cầu Giấy'},
            {'id': 'branch-02', 'name': 'Cơ sở Đống Đa'},
          ]);
        }
        if (r.url.path.endsWith('/dashboard')) {
          dashboardCalls++;
          queries.add(r.url.queryParameters['branchId']);
        }
        return handler(r) ?? json([]);
      }),
    );
    auth = AuthController(null, apiRepository: ApiAuthRepository(api));
    await auth.signIn(email: 'boss@example.com', password: 'x');
    appointments = ApiAppointmentProvider(ApiBookingRepository(api), auth);
    reports = ReportProvider(ReportRepository(api), auth, appointments);
  }

  Widget app() => MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: reports),
    ],
    child: const MaterialApp(home: BossOverviewScreen()),
  );

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    reports.dispose();
    appointments.dispose();
    auth.dispose();
    api.close();
  }
}

http.Response? _ok(http.Request r) {
  if (r.url.path.endsWith('/dashboard')) return json(dashboardJson());
  if (r.url.path.endsWith('/leaderboards')) return json(leaderboardsJson());
  return null;
}

Future<void> _size(WidgetTester tester, double w, double h) async {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('shows the data the API returned, nothing else is invented', (
    tester,
  ) async {
    await _size(tester, 1440, 900);
    final h = _Harness(_ok);
    await h.start();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.text('Tổng quan toàn chuỗi'), findsOneWidget);
    expect(find.text('Xin chào, Boss API  ·  Tháng 10/2026  ·  Hôm nay 31/10'),
        findsOneWidget);
    // Revenue: today, this month, previous month (exact, comma grouped).
    expect(find.text('1,500,000'), findsOneWidget);
    expect(find.text('18,450,000'), findsOneWidget);
    expect(find.text('Tháng trước: 42,300,000 VND'), findsOneWidget);
    // 18,450,000 / 42,300,000 = 43% of last month's revenue.
    expect(find.text('Bằng 43% doanh thu tháng trước'), findsOneWidget);
    // Month counters with their previous-month captions.
    expect(find.text('62'), findsOneWidget);
    expect(find.text('Tháng trước: 140'), findsOneWidget);
    expect(find.text('Tháng trước: 77'), findsOneWidget);
    expect(find.text('Tháng trước: 22'), findsOneWidget);
    // Rankings (preview of 5) and upcoming (preview of 6).
    expect(find.text('Cơ sở Cầu Giấy'), findsWidgets);
    expect(find.text('Nhân viên số 5'), findsOneWidget);
    expect(find.text('Nhân viên số 6'), findsNothing);
    expect(find.text('Khách số 5'), findsOneWidget);
    expect(find.text('Khách số 6'), findsNothing);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('"Xem tất cả" reveals every returned row, "Thu gọn" hides', (
    tester,
  ) async {
    await _size(tester, 1440, 1400);
    final h = _Harness(_ok);
    await h.start();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    Future<void> tapText(String text, {bool last = false}) async {
      final finder = last ? find.text(text).last : find.text(text);
      await tester.ensureVisible(finder);
      await tester.pumpAndSettle();
      await tester.tap(finder);
      await tester.pumpAndSettle();
    }

    await tapText('Xem tất cả (7)');
    expect(find.text('Nhân viên số 7'), findsOneWidget);
    await tapText('Xem tất cả (8)');
    expect(find.text('Khách số 7'), findsOneWidget);
    // Both lists are now expanded; the lower "Thu gọn" belongs to the upcoming list.
    await tapText('Thu gọn', last: true);
    expect(find.text('Khách số 7'), findsNothing);
    expect(find.text('Nhân viên số 7'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('keeps the exact API money string beyond the safe integer', (
    tester,
  ) async {
    await _size(tester, 1440, 900);
    final h = _Harness((r) {
      if (r.url.path.endsWith('/dashboard')) {
        return json(dashboardJson(monthRevenue: '9007199254740993'));
      }
      return _ok(r);
    });
    await h.start();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text('9,007,199,254,740,993'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('branch filter re-queries with branchId; error retries; '
      'a mutation refreshes the report', (tester) async {
    await _size(tester, 1440, 900);
    var failed = false;
    final h = _Harness((r) {
      if (failed && r.url.path.endsWith('/dashboard')) {
        return json({'message': 'Reports unavailable'}, 500);
      }
      return _ok(r);
    });
    await h.start();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(h.queries.last, isNull);

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cơ sở Đống Đa').last);
    await tester.pumpAndSettle();
    expect(h.queries.last, 'branch-02');

    failed = true;
    await tester.tap(find.text('Cập nhật'));
    await tester.pumpAndSettle();
    expect(find.text('Reports unavailable'), findsOneWidget);
    failed = false;
    await tester.tap(find.text('Thử lại').first);
    await tester.pumpAndSettle();
    expect(find.text('Reports unavailable'), findsNothing);
    expect(find.text('1,500,000'), findsOneWidget);

    final before = h.dashboardCalls;
    h.reports.appointments.recordMutation();
    await tester.pumpAndSettle();
    expect(h.dashboardCalls, greaterThan(before));

    h.auth.signOut();
    expect(h.reports.state('boss/dashboard', {}).data, isNull);
    await h.dispose(tester);
  });

  testWidgets('copes with sparse payloads and empty lists', (tester) async {
    await _size(tester, 1440, 900);
    final h = _Harness((r) {
      if (r.url.path.endsWith('/dashboard')) {
        return json({
          'today': {'revenueVnd': '0'},
          'month': {'revenueVnd': '0'},
        });
      }
      if (r.url.path.endsWith('/leaderboards')) {
        return json({'branches': [], 'staff': []});
      }
      return null;
    });
    await h.start();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text('Chưa có dữ liệu xếp hạng.'), findsNWidgets(2));
    expect(
      find.text('Không còn lịch hẹn nào sắp tới trong hôm nay.'),
      findsOneWidget,
    );
    expect(find.textContaining('Bằng'), findsNothing);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  for (final (name, w, hgt) in [
    ('mobile 360x740', 360.0, 740.0),
    ('small phone 320x568', 320.0, 568.0),
    ('tablet 820x1180', 820.0, 1180.0),
    ('desktop 1440x900', 1440.0, 900.0),
  ]) {
    testWidgets('lays out without overflow: $name (also at 1.6x text)', (
      tester,
    ) async {
      await _size(tester, w, hgt);
      final h = _Harness(_ok);
      await h.start();
      for (final scale in [1.0, 1.6]) {
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: Size(w, hgt),
              textScaler: TextScaler.linear(scale),
            ),
            child: h.app(),
          ),
        );
        await tester.pumpAndSettle();
        await tester.drag(find.byType(ListView).first, Offset(0, -hgt * 3));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$name @ ${scale}x');
      }
      await h.dispose(tester);
    });
  }
}
