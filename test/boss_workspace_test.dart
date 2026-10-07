import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/app.dart';
import 'package:ktgk/core/models/appointment.dart';
import 'package:ktgk/core/models/app_user.dart';
import 'package:ktgk/core/security/access_scope.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';
import 'package:ktgk/features/users/application/user_provider.dart';
import 'package:ktgk/features/branches/application/branch_provider.dart';
import 'package:ktgk/features/boss/application/boss_reports.dart';
import 'package:ktgk/features/boss/presentation/boss_main_screen.dart';
import 'package:ktgk/features/schedule/presentation/staff_main.dart';

class _FailOnceAuth extends MockAuthRepository {
  _FailOnceAuth({required super.users});
  bool fail = true;
  @override
  void addStaffCredentials(AppUser user, String password) {
    super.addStaffCredentials(user, password);
    if (fail) {
      fail = false;
      throw StateError('Allocation failed');
    }
  }
}

void main() {
  test('Vietnam day/month boundaries, status, hidden rows and commission are consistent', () {
    Appointment row(
      String id,
      DateTime date, {
      String branch = 'a',
      String staff = 'x',
      AppointmentStatus status = AppointmentStatus.completed,
    }) => Appointment(
      id: id,
      branchId: branch,
      staffId: staff,
      customerId: 'c',
      serviceIds: ['s'],
      serviceNamesSnapshot: ['Service'],
      startAt: date,
      endAt: date.add(const Duration(minutes: 30)),
      totalPriceVnd: 100001,
      status: status,
      isHiddenByCustomer: true,
      isHiddenByStaff: true,
    );
    final rows = [
      row('before', DateTime.utc(2029, 12, 31, 16, 59)),
      row('start', DateTime.utc(2029, 12, 31, 17)),
      row('today', DateTime.utc(2030, 1, 2, 3)),
      row(
        'cancelled',
        DateTime.utc(2030, 1, 2, 4),
        status: AppointmentStatus.cancelled,
      ),
      row('end', DateTime.utc(2030, 1, 31, 17)),
      row('other', DateTime.utc(2030, 1, 2, 6), branch: 'b', staff: 'y'),
    ];
    final now = DateTime.utc(2030, 1, 2, 5);
    final day = BossReports.totals(BossReports.period(rows, now));
    final month = BossReports.period(rows, now, month: true);
    expect(day, (appointments: 3, revenue: 200002));
    expect(BossReports.totals(month), (appointments: 4, revenue: 300003));
    expect(BossReports.rankings(month).first.id, 'a');
    expect(BossReports.rankings(month, byStaff: true).first.count, 2);
    expect(BossReports.commission(100001, 30), 30000);
    expect(() => BossReports.commission(1, 101), throwsArgumentError);
  });

  test('Boss approves same ID, manager is denied, retry and duplicate approval remain safe', () async {
    final raw = MockUserRepository();
    final authentication = _FailOnceAuth(users: raw);
    final auth = AuthController(authentication);
    final scope = AccessScope(() => auth.currentUser, changes: auth);
    final users = UserProvider(
      raw,
      auth: authentication,
      access: scope,
      hasAppointments: (_) => false,
    );
    addTearDown(() {
      users.dispose();
      scope.dispose();
      auth.dispose();
      raw.dispose();
    });
    await auth.signIn(email: 'admin@example.com', password: 'admin123');
    final recruited = users.createStaffProfile(
      name: 'New Crew',
      email: 'crew@example.com',
      phone: '0901234567',
      address: 'Hà Nội',
      specializedCategoryIds: ['haircut'],
    );
    expect(
      authentication.signIn(email: recruited.email, password: 'crew123'),
      isNull,
    );
    expect(
      () => users.approveStaff('staff-06', 'allocated123'),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(
      () => users.rejectPendingStaff('staff-06'),
      throwsA(isA<UnauthorizedException>()),
    );
    await auth.signIn(email: 'boss@example.com', password: 'boss123');
    expect(() => users.approveStaff('staff-06', ' '), throwsArgumentError);
    expect(
      () => users.approveStaff('staff-06', 'allocated123'),
      throwsStateError,
    );
    expect(raw.getById('staff-06')!.isApproved, isFalse);
    expect(authentication.hasCredentials('staff-06'), isFalse);
    users.approveStaff('staff-06', 'allocated123');
    expect(raw.getById('staff-06')!.isApproved, isTrue);
    expect(
      authentication
          .signIn(email: 'pending@example.com', password: 'allocated123')!
          .id,
      'staff-06',
    );
    expect(() => users.approveStaff('staff-06', 'different'), throwsStateError);
    expect(() => users.rejectPendingStaff('staff-06'), throwsStateError);
    users.rejectPendingStaff('staff-02');
    expect(raw.getById('staff-02'), isNull);
    expect(authentication.hasCredentials('staff-02'), isFalse);
    users.approveStaff(recruited.id, 'crew123');
    expect(
      authentication.signIn(email: recruited.email, password: 'crew123')!.id,
      recruited.id,
    );
    await auth.signIn(email: 'pending@example.com', password: 'allocated123');
    expect(auth.currentUser!.branchId, 'branch-01');
  });

  test('Reject protects pending profiles with appointments or existing credentials', () async {
    final raw = MockUserRepository();
    final authentication = MockAuthRepository(users: raw);
    final auth = AuthController(authentication);
    final scope = AccessScope(() => auth.currentUser, changes: auth);
    final users = UserProvider(
      raw,
      auth: authentication,
      access: scope,
      hasAppointments: (id) => id == 'staff-06',
    );
    addTearDown(() {
      users.dispose();
      scope.dispose();
      auth.dispose();
      raw.dispose();
    });
    await auth.signIn(email: 'boss@example.com', password: 'boss123');
    expect(() => users.rejectPendingStaff('staff-06'), throwsStateError);
    authentication.addStaffCredentials(raw.getById('staff-02')!, 'password');
    expect(() => users.rejectPendingStaff('staff-02'), throwsStateError);
    expect(raw.getById('staff-02'), isNotNull);
  });

  Future<void> login(WidgetTester tester) async {
    await tester.pumpWidget(const BarbershopApp(useMock: true));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'boss@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'boss123');
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Login'));
    await tester.tap(find.widgetWithText(FilledButton, 'Login'));
    await tester.pumpAndSettle();
    expect(find.byType(BossMainScreen), findsOneWidget);
  }

  Future<void> tab(WidgetTester tester, String label) async {
    final target = find.widgetWithText(Tab, label);
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Boss small-phone tabs, branch filter, ledger badges and commission slider',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await login(tester);
      expect(find.text('Tổng hành dinh'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cơ sở Đống Đa').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Doanh thu hôm nay'));
      await tester.pumpAndSettle();
      expect(find.text('0đ'), findsWidgets);
      await tab(tester, 'Sổ lịch');
      await tester.tap(find.widgetWithText(ChoiceChip, 'Hoàn thành'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Nguyễn Minh Hùng'));
      await tester.pumpAndSettle();
      expect(find.text('Cơ sở Cầu Giấy'), findsWidgets);
      expect(find.text('Nguyễn Minh Hùng'), findsOneWidget);
      await tab(tester, 'Hoa hồng');
      expect(find.text('Hoa hồng tạm tính · 30%'), findsOneWidget);
      await tester.tap(find.byType(Slider));
      await tester.pumpAndSettle();
      expect(find.text('Hoa hồng tạm tính · 50%'), findsOneWidget);
      await tab(tester, 'Dịch vụ');
      expect(find.byTooltip('Thêm dịch vụ'), findsOneWidget);
      await tab(tester, 'Tổng quan');
      await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>).first,
            )
            .initialValue,
        'branch-02',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Boss approval dialog validates, removes pending and staff logs in',
    (tester) async {
      await login(tester);
      await tab(tester, 'Phê duyệt');
      final users = tester
          .element(find.byType(BossMainScreen))
          .read<UserProvider>();
      await tester.tap(find.widgetWithText(FilledButton, 'Duyệt').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Duyệt').last);
      await tester.pumpAndSettle();
      expect(find.text('Vui lòng nhập mật khẩu.'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), 'allocated123');
      await tester.tap(find.widgetWithText(FilledButton, 'Duyệt').last);
      await tester.pumpAndSettle();
      expect(users.getById('staff-06')!.isApproved, isTrue);
      expect(find.text('Pending Staff'), findsNothing);
      await tester.tap(find.byTooltip('Đăng xuất'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'pending@example.com',
      );
      await tester.enterText(find.byType(TextFormField).at(1), 'allocated123');
      await tester.tap(find.widgetWithText(FilledButton, 'Login'));
      await tester.pumpAndSettle();
      expect(find.byType(StaffMain), findsOneWidget);
    },
  );

  testWidgets(
    'Boss rejection asks confirmation and deletes only the pending profile',
    (tester) async {
      await login(tester);
      await tab(tester, 'Phê duyệt');
      final users = tester
          .element(find.byType(BossMainScreen))
          .read<UserProvider>();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Từ chối').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();
      expect(users.getById('staff-06'), isNotNull);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Từ chối').first);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Từ chối'));
      await tester.pumpAndSettle();
      expect(users.getById('staff-06'), isNull);
      expect(find.text('Pending Staff'), findsNothing);
      expect(users.getById('staff-01')!.isApproved, isTrue);
    },
  );

  testWidgets('Boss branch add/edit/delete and protected referenced branch', (
    tester,
  ) async {
    await login(tester);
    await tab(tester, 'Cơ sở');
    final branches = tester
        .element(find.byType(BossMainScreen))
        .read<BranchProvider>();
    final initialCount = branches.branches.length;
    await tester.tap(find.text('Thêm cơ sở'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập thông tin.'), findsNWidgets(3));
    for (final e in ['Cơ sở mới', 'Hà Nội', '0901234567'].asMap().entries) {
      await tester.enterText(find.byType(TextFormField).at(e.key), e.value);
    }
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(branches.branches, hasLength(initialCount + 1));
    final name = find.text('Cơ sở mới');
    await tester.scrollUntilVisible(
      name,
      250,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    final panel = find.ancestor(of: name, matching: find.byType(Column)).first;
    await tester.tap(
      find.descendant(
        of: panel,
        matching: find.widgetWithText(TextButton, 'Sửa'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Cơ sở sửa');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(branches.branches.last.name, 'Cơ sở sửa');
    await tester.tap(find.widgetWithText(TextButton, 'Xóa').last);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(branches.branches, hasLength(initialCount));
    await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Xóa').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
    await tester.pumpAndSettle();
    expect(find.text('Chi nhánh còn nhân sự hoặc lịch hẹn.'), findsOneWidget);
    expect(branches.branches, hasLength(initialCount));
    expect(tester.takeException(), isNull);
  });
}
