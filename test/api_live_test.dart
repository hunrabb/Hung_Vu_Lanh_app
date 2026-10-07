import 'dart:io';
import 'dart:convert';

import 'package:ktgk/features/booking/data/api_booking_repository.dart';
import 'package:ktgk/features/booking/application/api_appointment_provider.dart';
import 'package:ktgk/features/reports/data/report_repository.dart';
import 'package:ktgk/features/reports/application/report_provider.dart';
import 'package:ktgk/core/network/api_money.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/io_client.dart';
import 'package:ktgk/core/models/app_user.dart';
import 'package:ktgk/core/network/api_client.dart';
import 'package:ktgk/core/network/token_store.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/api_auth_repository.dart';
import 'package:ktgk/features/boss/application/pending_staff_provider.dart';
import 'package:ktgk/features/boss/data/api_pending_staff_repository.dart';
import 'package:ktgk/features/workspace/application/workspace_provider.dart';
import 'package:ktgk/features/workspace/data/workspace_repository.dart';
import 'package:ktgk/features/users/application/leave_request.dart';

class _Memory implements TokenPersistence {
  String? token;
  @override
  Future<String?> read() async => token;
  @override
  Future<void> write(String value) async {
    token = value;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

class _RealHttp extends HttpOverrides {}

void main() {
  test(
    'LIVE Flutter Auth + Boss pending list through actual Nest API',
    () async {
      final api = ApiClient(
        tokens: TokenStore(_Memory()),
        client: IOClient(_RealHttp().createHttpClient(null)),
        baseUrl: 'http://localhost:3000/api',
      );
      final auth = AuthController(null, apiRepository: ApiAuthRepository(api));
      PendingStaffProvider? pending;
      WorkspaceProvider? workspace;
      ApiAppointmentProvider? appointments;
      ReportProvider? reports;
      final appointmentIds = <String>[];
      String? fixtureId;
      try {
        expect(
          await auth.signIn(email: 'boss@example.com', password: 'boss123'),
          true,
        );
        expect(auth.currentUser!.role, UserRole.superAdmin);
        pending = PendingStaffProvider(ApiPendingStaffRepository(api), auth);
        await Future<void>.delayed(Duration.zero);
        while (pending.isLoading) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
        expect(pending.error, isNull);
        expect(pending.rows.length, greaterThanOrEqualTo(5));
        expect(pending.branchNames.length, 4);
        expect(
          await auth.signIn(email: 'admin@example.com', password: 'admin123'),
          true,
        );
        final email =
            'phase6-${DateTime.now().microsecondsSinceEpoch}@example.com';
        final created = await api.request(
          'POST',
          'users/staff',
          body: {
            'name': 'Phase6 Flutter fixture',
            'email': email,
            'phone': '0901234567',
            'address': 'Ha Noi',
            'specializedCategoryIds': ['haircut'],
          },
        ) as Map;
        fixtureId = created['id'] as String;
        expect(
          await auth.signIn(email: 'boss@example.com', password: 'boss123'),
          true,
        );
        await pending.refresh();
        expect(pending.rows.any((u) => u.id == fixtureId), true);
        await pending.decide(fixtureId, password: 'Phase6Staff123');
        expect(pending.rows.any((u) => u.id == fixtureId), false);
        expect(
          await auth.signIn(email: email, password: 'Phase6Staff123'),
          true,
        );
        expect(auth.currentUser!.id, fixtureId);
        expect(auth.currentUser!.role, UserRole.staff);
        workspace = WorkspaceProvider(WorkspaceRepository(api), auth);
        final today = DateTime.now().toUtc().add(const Duration(hours: 7));
        final start = DateTime.utc(
          today.year,
          today.month,
          today.day + 1,
          8,
        ).subtract(const Duration(hours: 7));
        await workspace.requestLeave(
          start,
          start.add(const Duration(hours: 4)),
          'Phase6 live leave',
        );
        expect(
          await auth.signIn(email: 'admin@example.com', password: 'admin123'),
          true,
        );
        await workspace.refresh();
        final leave = workspace.leaves.firstWhere(
          (r) => r.staffId == fixtureId,
        );
        expect(leave.status, LeaveStatus.pending);
        await workspace.decide(leave.id, true, 'Live Flutter approval');
        final decided = workspace.leaves.firstWhere((r) => r.id == leave.id);
        expect(decided.status, LeaveStatus.approved);
        expect(decided.reviewedByName, auth.currentUser!.name);
        expect(decided.reviewedAt, isNotNull);
        final shiftStart = start.add(const Duration(days: 1));
        await workspace.saveShift(
          fixtureId,
          shiftStart,
          shiftStart.add(const Duration(hours: 8)),
        );
        final shift = workspace.shifts.firstWhere(
          (s) => s.staffId == fixtureId,
        );
        expect(shift.branchId, 'branch-01');
        await workspace.saveShift(
          fixtureId,
          shiftStart,
          shiftStart.add(const Duration(hours: 9)),
          id: shift.id,
        );
        expect(
          await auth.signIn(email: email, password: 'Phase6Staff123'),
          true,
        );
        await workspace.refresh();
        expect(workspace.shifts.single.id, shift.id);
        expect(workspace.leaves.single.status, LeaveStatus.approved);
        expect(
          await auth.signIn(
            email: 'customer@example.com',
            password: 'customer123',
          ),
          true,
        );
        final booking = ApiBookingRepository(api);
        appointments = ApiAppointmentProvider(booking, auth);
        await appointments.catalog();
        final service = appointments.services.firstWhere(
          (s) => s['categoryId'] == 'haircut' && (s['duration'] as int) <= 90,
        );
        final eligible = await booking.staff(
          'branch-01',
          service['id'] as String,
        );
        expect(eligible.any((s) => s['id'] == fixtureId), true);
        final date = shiftStart
            .add(const Duration(hours: 7))
            .toIso8601String()
            .substring(0, 10);
        final slots = await booking.slots(
          'branch-01',
          fixtureId,
          service['id'] as String,
          date,
        );
        expect(slots, isNotEmpty);
        final attempts = await Future.wait([
          for (var i = 0; i < 2; i++)
            booking
                .book(
                  branch: 'branch-01',
                  staff: fixtureId,
                  service: service['id'] as String,
                  start: slots.first['startAt'] as String,
                )
                .then<Object>(
                  (result) => result,
                  onError: (Object error) => error,
                ),
        ]);
        expect(attempts.whereType<ApiAppointment>().length, 1);
        expect(attempts.whereType<ApiException>().single.statusCode, 409);
        final booked = attempts.whereType<ApiAppointment>().single;
        appointmentIds.add(booked.id);
        expect(
          ApiMoney.bigInt(booked.price),
          ApiMoney.bigInt(service['price']),
        );
        final cancelled = await booking.book(
          branch: 'branch-01',
          staff: fixtureId,
          service: service['id'] as String,
          start: booked.endAt.toIso8601String(),
        );
        appointmentIds.add(cancelled.id);
        await booking.act(cancelled.id, 'cancel');
        expect(
          (await booking.list(1))
              .firstWhere((a) => a.id == cancelled.id)
              .status,
          'cancelled',
        );
        expect(
          await auth.signIn(email: 'admin@example.com', password: 'admin123'),
          true,
        );
        final walk = await booking.book(
          branch: 'branch-01',
          staff: fixtureId,
          service: service['id'] as String,
          start: cancelled.startAt.toIso8601String(),
          walkIn: true,
          contact: 'Phase6 Walk-in / 0901234567',
        );
        appointmentIds.add(walk.id);
        expect(walk.data['customerId'], isNull);
        expect(walk.branchId, 'branch-01');
        await expectLater(
          workspace.deleteShift(shift.id),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'status', 409),
          ),
        );
        expect(
          await auth.signIn(email: email, password: 'Phase6Staff123'),
          true,
        );
        await appointments.act(booked.id, 'complete');
        await appointments.act(walk.id, 'no-show');
        reports = ReportProvider(ReportRepository(api), auth, appointments);
        final reportQuery = {
          'from': date,
          'to': date,
          'page': '1',
          'limit': '50',
        };
        await reports.load('staff/me/earnings', reportQuery);
        final staffEarnings = reports.state('staff/me/earnings', reportQuery);
        expect(staffEarnings.error, isNull);
        expect(
          (staffEarnings.data!['transactions'] as List).single['id'],
          booked.id,
        );
        await reports.load('staff/me/profile-stats', {
          'page': '1',
          'limit': '50',
        });
        final stats = reports.state('staff/me/profile-stats', {
          'page': '1',
          'limit': '50',
        }).data!;
        expect(stats['registeredCustomerCount'], 1);
        expect(
          (stats['customers'] as List).single['totalSpentVnd'],
          booked.price,
        );
        expect(
          (await booking.list(1)).firstWhere((a) => a.id == walk.id).status,
          'noShow',
        );
        expect(
          (await booking.list(1)).firstWhere((a) => a.id == booked.id).status,
          'completed',
        );
        expect(
          await auth.signIn(email: 'admin@example.com', password: 'admin123'),
          true,
        );
        await reports.load('manager/dashboard', {});
        expect(reports.state('manager/dashboard', {}).error, isNull);
        await reports.load('manager/revenue', reportQuery);
        final revenue = reports.state('manager/revenue', reportQuery).data!;
        expect(
          (revenue['staffRanking'] as List).firstWhere(
            (r) => r['staffId'] == fixtureId,
          )['revenueVnd'],
          booked.price,
        );
        expect(
          await auth.signIn(email: 'boss@example.com', password: 'boss123'),
          true,
        );
        await reports.load('boss/dashboard', {});
        expect(reports.state('boss/dashboard', {}).error, isNull);
        final bossQuery = {...reportQuery, 'branchId': 'branch-01'};
        await reports.load('boss/leaderboards', bossQuery);
        expect(reports.state('boss/leaderboards', bossQuery).error, isNull);
        await reports.load('boss/appointments', bossQuery);
        expect(
          (reports.state('boss/appointments', bossQuery).data!['appointments']
                  as List)
              .any((r) => r['id'] == booked.id),
          true,
        );
        await reports.load('boss/commissions', bossQuery);
        final commission =
            (reports.state('boss/commissions', bossQuery).data!['staff']
                    as List)
                .firstWhere((r) => r['staffId'] == fixtureId);
        expect(
          commission['commissionVnd'],
          (ApiMoney.bigInt(booked.price) * BigInt.from(30) ~/ BigInt.from(100))
              .toString(),
        );
        // Completed appointments keep the occupied shift protected until test cleanup.
        // Only the temporary fixture is approved; the five seed profiles stay pending.
        await auth.apiRepository!.logout();
        expect(await api.tokens.read(), null);
      } finally {
        pending?.dispose();
        workspace?.dispose();
        appointments?.dispose();
        reports?.dispose();
        auth.dispose();
        api.close();
        if (fixtureId != null) {
          final cleanup = await Process.run('node', [
            '-e',
            r'''
require('dotenv/config');const fs=require('node:fs');const {Client}=require('pg');
const c=new Client({host:process.env.DB_HOST,port:Number(process.env.DB_PORT),database:process.env.DB_NAME,user:process.env.DB_USER,password:process.env.DB_PASSWORD,ssl:{rejectUnauthorized:true,ca:fs.readFileSync('./ca.pem','utf8')}});
(async()=>{try{await c.connect();await c.query('BEGIN');const owned=await c.query("SELECT id FROM users WHERE id=$1 AND name='Phase6 Flutter fixture' AND email LIKE 'phase6-%@example.com'",[process.argv[1]]);if(owned.rows.length){await c.query('DELETE FROM appointments WHERE id=ANY($1::text[]) AND staff_id=$2',[JSON.parse(process.argv[2]),process.argv[1]]);await c.query('DELETE FROM staff_leave_requests WHERE staff_id=$1',[process.argv[1]]);await c.query('DELETE FROM staff_shifts WHERE staff_id=$1',[process.argv[1]]);}await c.query("DELETE FROM users WHERE id=$1 AND name='Phase6 Flutter fixture' AND email LIKE 'phase6-%@example.com'",[process.argv[1]]);await c.query('COMMIT');}catch(e){await c.query('ROLLBACK').catch(()=>{});console.error(e.code||'cleanup failed');process.exitCode=1;}finally{await c.end();}})();
''',
            fixtureId,
            jsonEncode(appointmentIds),
          ], workingDirectory: 'backend');
          expect(cleanup.exitCode, 0, reason: cleanup.stderr.toString());
        }
      }
    },
    skip: !const bool.fromEnvironment('RUN_LIVE_API_TEST'),
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
