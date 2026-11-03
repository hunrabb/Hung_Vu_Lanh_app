import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/network/api_client.dart';
import 'package:ktgk/core/network/token_store.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/api_auth_repository.dart';
import 'package:ktgk/features/boss/presentation/boss_ledger_api_screen.dart';
import 'package:ktgk/features/booking/application/api_appointment_provider.dart';
import 'package:ktgk/features/booking/data/api_booking_repository.dart';
import 'package:ktgk/features/reports/application/report_provider.dart';
import 'package:ktgk/features/reports/data/report_repository.dart';

import 'api_integration_test.dart' show MemoryTokens, profile, json;

/// Mirrors one entry of `ReportsService.ledger` on the backend.
Map<String, dynamic> ledgerRow(int i, {String? status}) {
  // Three rows per Hanoi day (09:00, 11:00, 13:00), newest first.
  final day = 31 - (i ~/ 3);
  final utcHour = 2 + (i % 3) * 2;
  String iso(int hour) =>
      DateTime.utc(2026, 10, day, hour).toIso8601String();
  return {
    'id': 'a$i',
    'branchId': 'branch-01',
    'branchName': 'Cơ sở Cầu Giấy',
    'staffId': 'staff-01',
    'staffName': 'Nguyễn Minh Hùng',
    'customerId': i % 4 == 3 ? null : 'c$i',
    'customerName': 'Khách số $i',
    'startAt': iso(utcHour),
    'endAt': iso(utcHour + 1),
    'status': status ?? const ['completed', 'confirmed', 'pending', 'cancelled', 'noShow'][i % 5],
    'totalPriceVnd': '${80000 + i * 10000}',
    'services': [
      {'serviceId': 's1', 'name': 'Cắt tóc nam'},
      if (i.isEven) {'serviceId': 's2', 'name': 'Gội đầu thư giãn'},
    ],
  };
}

Map<String, dynamic> ledgerJson(int count, {int page = 1, String? status}) => {
  'period': {
    'from': '2026-09-30T17:00:00.000Z',
    'to': '2026-10-31T17:00:00.000Z',
  },
  'page': page,
  'limit': 50,
  'appointments': [for (var i = 0; i < count; i++) ledgerRow(i, status: status)],
};

class _Harness {
  _Harness(this.handler);
  final http.Response? Function(http.Request) handler;
  final queries = <Map<String, String>>[];
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
        if (r.url.path.endsWith('/boss/appointments')) {
          queries.add(Map.of(r.url.queryParameters));
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
    child: const MaterialApp(home: BossLedgerApiScreen()),
  );

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    reports.dispose();
    appointments.dispose();
    auth.dispose();
    api.close();
  }
}

http.Response? _ok(http.Request r) =>
    r.url.path.endsWith('/boss/appointments') ? json(ledgerJson(6)) : null;

Future<void> _size(WidgetTester tester, double w, double h) async {
  tester.view.physicalSize = Size(w, h);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('groups rows by Hanoi day and shows every field of each row', (
    tester,
  ) async {
    await _size(tester, 1440, 1400);
    final h = _Harness(_ok);
    await h.start();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    // Default request: current period, page 1, 50 per page, no filters.
    expect(h.queries.single, {'page': '1', 'limit': '50'});
    expect(find.text('Sổ lịch'), findsOneWidget);
    expect(find.text('01/10/2026 – 31/10/2026  ·  6 lịch hẹn'), findsOneWidget);
    // Two Hanoi days of three rows each (31/10 is a Saturday, 30/10 a Friday).
    expect(find.text('Thứ Bảy, 31/10/2026'), findsOneWidget);
    expect(find.text('Thứ Sáu, 30/10/2026'), findsOneWidget);
    expect(find.text('3 lịch'), findsNWidgets(2));
    // 02:00Z is 09:00 in Hanoi.
    expect(find.text('09:00'), findsNWidgets(2));
    expect(find.text('Khách số 0'), findsOneWidget);
    expect(find.text('Nguyễn Minh Hùng'), findsWidgets);
    expect(find.text('Cơ sở Cầu Giấy'), findsWidgets);
    expect(find.text('Cắt tóc nam, Gội đầu thư giãn'), findsWidgets);
    expect(find.text('80,000 VND'), findsOneWidget);
    // Status labels come from the existing appointment label map.
    expect(find.text('Hoàn thành'), findsWidgets);
    expect(find.text('Đã xác nhận'), findsWidgets);
    // Row 3 has no customerId -> walk-in.
    expect(find.text('Vãng lai'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('status pills and branch filter re-query and reset to page 1', (
    tester,
  ) async {
    await _size(tester, 1440, 1000);
    final h = _Harness(_ok);
    await h.start();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Hoàn thành').first);
    await tester.pumpAndSettle();
    expect(h.queries.last, {'status': 'completed', 'page': '1', 'limit': '50'});

    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cơ sở Đống Đa').last);
    await tester.pumpAndSettle();
    expect(h.queries.last, {
      'branchId': 'branch-02',
      'status': 'completed',
      'page': '1',
      'limit': '50',
    });

    await tester.tap(find.text('Tất cả'));
    await tester.pumpAndSettle();
    expect(h.queries.last.containsKey('status'), isFalse);
    expect(h.queries.last['branchId'], 'branch-02');
    await h.dispose(tester);
  });

  testWidgets('date range sends from/to and labels the button', (tester) async {
    await _size(tester, 800, 1280);
    final h = _Harness(_ok);
    await h.start();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text('Tháng này'), findsOneWidget);

    await tester.tap(find.text('Tháng này'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10').first);
    await tester.pump();
    await tester.tap(find.text('12').first);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    expect(h.queries.last['from'], '${now.year}-$month-10');
    expect(h.queries.last['to'], '${now.year}-$month-12');
    expect(h.queries.last['page'], '1');
    expect(find.text('10/$month – 12/$month/${now.year}'), findsOneWidget);
    await h.dispose(tester);
  });

  testWidgets('paging: 50 rows enable "Sau"; "Trước" returns to page 1', (
    tester,
  ) async {
    await _size(tester, 1440, 1000);
    final h = _Harness((r) {
      if (!r.url.path.endsWith('/boss/appointments')) return null;
      final page = int.parse(r.url.queryParameters['page']!);
      return json(ledgerJson(page == 1 ? 50 : 4, page: page));
    });
    await h.start();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    Future<void> tapText(String text) async {
      await tester.ensureVisible(find.text(text));
      await tester.pumpAndSettle();
      await tester.tap(find.text(text));
      await tester.pumpAndSettle();
    }

    expect(find.text('Trang 1'), findsOneWidget);
    await tapText('Sau');
    expect(h.queries.last['page'], '2');
    expect(find.text('Trang 2'), findsOneWidget);
    // Page 2 returned fewer than 50 rows, so there is no next page.
    await tester.ensureVisible(find.text('Sau'));
    final next = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Sau'),
    );
    expect(next.onPressed, isNull);
    await tapText('Trước');
    expect(h.queries.last['page'], '1');
    await h.dispose(tester);
  });

  testWidgets('a short single page shows no pager', (tester) async {
    await _size(tester, 1440, 1000);
    final h = _Harness(_ok);
    await h.start();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text('Trang 1'), findsNothing);
    await h.dispose(tester);
  });

  testWidgets('error shows retry and recovers; a mutation refreshes the list', (
    tester,
  ) async {
    await _size(tester, 1440, 1000);
    var failed = true;
    final h = _Harness((r) {
      if (!r.url.path.endsWith('/boss/appointments')) return null;
      return failed
          ? json({'message': 'Ledger unavailable'}, 500)
          : json(ledgerJson(6));
    });
    await h.start();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text('Ledger unavailable'), findsOneWidget);

    failed = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Ledger unavailable'), findsNothing);
    expect(find.text('Khách số 0'), findsOneWidget);

    final before = h.queries.length;
    h.reports.appointments.recordMutation();
    await tester.pumpAndSettle();
    expect(h.queries.length, greaterThan(before));
    await h.dispose(tester);
  });

  testWidgets('empty period shows a helpful empty state', (tester) async {
    await _size(tester, 1440, 1000);
    final h = _Harness((r) => r.url.path.endsWith('/boss/appointments')
        ? json(ledgerJson(0))
        : null);
    await h.start();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text('Chưa có lịch hẹn nào trong kỳ này.'), findsOneWidget);
    expect(
      find.text('Thử đổi cơ sở, trạng thái hoặc khoảng ngày.'),
      findsOneWidget,
    );
    await h.dispose(tester);
  });

  testWidgets('copes with sparse rows (missing names, services, price)', (
    tester,
  ) async {
    await _size(tester, 360, 800);
    final h = _Harness((r) => r.url.path.endsWith('/boss/appointments')
        ? json({
            'appointments': [
              {'id': 'x', 'status': 'weird', 'customerId': 'c'},
            ],
          })
        : null);
    await h.start();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();
    expect(find.text('Không rõ ngày'), findsOneWidget);
    expect(find.text('weird'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  testWidgets('narrow top bar: title and actions share a row, filters live in '
      'a sheet that still drives the report query', (tester) async {
    await _size(tester, 390, 844);
    final h = _Harness(_ok);
    await h.start();
    // The Material date-range picker's own header overflows at this width under
    // the wide `Ahem` test font. Ignore only that, only while it is open.
    var pickerOpen = false;
    final prior = FlutterError.onError;
    FlutterError.onError = (details) {
      if (pickerOpen &&
          details.exception.toString().contains('RenderFlex overflowed')) {
        return;
      }
      prior?.call(details);
    };
    addTearDown(() => FlutterError.onError = prior);
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    // Branch and period are no longer inline on narrow screens.
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    final title = tester.getRect(find.text('Sổ lịch'));
    final filter = tester.getRect(find.byTooltip('Bộ lọc'));
    final refresh = tester.getRect(find.byTooltip('Cập nhật'));
    // One row: actions sit on the title's line, at the right edge (16 gutter).
    expect((title.center.dy - filter.center.dy).abs(), lessThan(2));
    expect(filter.center.dy, refresh.center.dy);
    expect(refresh.right, closeTo(390 - 16, 0.5));
    expect(title.right, lessThanOrEqualTo(filter.left));
    expect(filter.right, lessThanOrEqualTo(refresh.left));
    expect(find.descendant(of: find.byType(Badge), matching: find.text('1')),
        findsNothing);

    await tester.tap(find.byTooltip('Bộ lọc'));
    await tester.pumpAndSettle();
    expect(find.text('Bộ lọc'), findsOneWidget);
    expect(find.text('Cơ sở'), findsOneWidget);
    expect(find.text('Kỳ báo cáo'), findsOneWidget);

    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cơ sở Đống Đa').last);
    await tester.pumpAndSettle();
    expect(h.queries.last['branchId'], 'branch-02');
    expect(h.queries.last['page'], '1');

    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
    expect(find.text('Bộ lọc'), findsNothing);
    // The active filter is announced on the button and in the summary line.
    expect(find.descendant(of: find.byType(Badge), matching: find.text('1')),
        findsOneWidget);
    expect(find.text('Cơ sở Đống Đa'), findsOneWidget);

    // Period: picked from the same sheet, applied immediately.
    await tester.tap(find.byTooltip('Bộ lọc'));
    await tester.pumpAndSettle();
    pickerOpen = true;
    await tester.tap(find.text('Tháng này'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10').first);
    await tester.pump();
    await tester.tap(find.text('12').first);
    await tester.pump();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    pickerOpen = false;
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    expect(h.queries.last['from'], '${now.year}-$month-10');
    expect(h.queries.last['to'], '${now.year}-$month-12');
    expect(h.queries.last['branchId'], 'branch-02');
    expect(find.text('10/$month – 12/$month/${now.year}'), findsOneWidget);
    await tester.tap(find.text('Xong'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(Badge), matching: find.text('2')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    await h.dispose(tester);
  });

  for (final w in [320.0, 360.0, 390.0, 412.0]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets('top bar stays inside the screen: ${w.toInt()}dp @${scale}x', (
        tester,
      ) async {
        await _size(tester, w, 800);
        final h = _Harness(_ok);
        await h.start();
        await tester.pumpWidget(
          MediaQuery(
            data: MediaQueryData(
              size: Size(w, 800),
              textScaler: TextScaler.linear(scale),
            ),
            child: h.app(),
          ),
        );
        await tester.pumpAndSettle();

        final title = tester.getRect(find.text('Sổ lịch'));
        final filter = tester.getRect(find.byTooltip('Bộ lọc'));
        final refresh = tester.getRect(find.byTooltip('Cập nhật'));
        final count = tester.getRect(find.text('6 lịch hẹn'));
        for (final (label, r) in [
          ('title', title),
          ('filter', filter),
          ('refresh', refresh),
          ('count', count),
        ]) {
          expect(r.left, greaterThanOrEqualTo(0), reason: '$label left');
          expect(r.right, lessThanOrEqualTo(w), reason: '$label right');
        }
        // Nothing overlaps on the title row.
        expect(title.right, lessThanOrEqualTo(filter.left));
        expect(filter.right, lessThanOrEqualTo(refresh.left));
        // Touch targets stay at least 48dp.
        expect(filter.width, greaterThanOrEqualTo(48));
        expect(refresh.height, greaterThanOrEqualTo(48));
        expect(tester.takeException(), isNull);
        await h.dispose(tester);
      });
    }
  }

  testWidgets('respects SafeArea insets (notch / status bar / landscape cut-out)',
      (tester) async {
    await _size(tester, 390, 844);
    final h = _Harness(_ok);
    await h.start();
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.fromLTRB(24, 40, 24, 0),
        ),
        child: h.app(),
      ),
    );
    await tester.pumpAndSettle();
    final title = tester.getRect(find.text('Sổ lịch'));
    final refresh = tester.getRect(find.byTooltip('Cập nhật'));
    expect(title.left, greaterThanOrEqualTo(24 + 16));
    expect(title.top, greaterThanOrEqualTo(40));
    expect(refresh.right, lessThanOrEqualTo(390 - 24 - 16 + 0.5));
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
        final error = tester.takeException();
        expect(
          error,
          isNull,
          reason: '$name @ ${scale}x\n'
              '${error is FlutterError ? error.toStringDeep() : error}',
        );
      }
      await h.dispose(tester);
    });
  }
}
