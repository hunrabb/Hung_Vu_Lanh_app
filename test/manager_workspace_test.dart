import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/security/access_scope.dart';
import 'package:ktgk/core/models/appointment.dart';
import 'package:ktgk/core/routing/app_router.dart';
import 'package:ktgk/core/routing/app_routes.dart';
import 'package:ktgk/features/manager/presentation/manager_revenue_screen.dart';
import 'package:ktgk/features/users/application/leave_request.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';
import 'package:ktgk/features/users/application/user_provider.dart';
import 'package:ktgk/features/catalog/data/mock_service_repository.dart';
import 'package:ktgk/features/catalog/application/service_provider.dart';
import 'package:ktgk/features/booking/data/mock_appointment_repository.dart';
import 'package:ktgk/features/booking/application/appointment_provider.dart';
import 'package:ktgk/features/branches/data/mock_branch_repository.dart';
import 'package:ktgk/features/branches/application/branch_provider.dart';
import 'package:ktgk/features/settings/application/shop_settings_provider.dart';
import 'package:ktgk/features/manager/presentation/manager_main.dart';

void main() {
  late MockUserRepository rawUsers;
  late MockAuthRepository authentication;
  late AuthController auth;
  late AccessScope scope;
  late UserProvider users;
  late ServiceProvider services;
  late ShopSettingsProvider settings;
  late AppointmentProvider booking;
  late BranchProvider branches;
  setUp(() {
    rawUsers = MockUserRepository();
    authentication = MockAuthRepository(users: rawUsers);
    auth = AuthController(authentication);
    scope = AccessScope(() => auth.currentUser, changes: auth);
    final seeds = MockAppointmentRepository(now: DateTime.utc(2030, 1, 2, 3))
        .getAll();
    final appointments = MockAppointmentRepository(
      initialData: [
        ...seeds,
        seeds.first.copyWith(
          id: 'month-start',
          staffId: 'staff-03',
          startAt: DateTime.utc(2029, 12, 31, 17),
          endAt: DateTime.utc(2029, 12, 31, 17, 45),
          totalPriceVnd: 300000,
          isHiddenByCustomer: true,
          isHiddenByStaff: true,
        ),
        seeds.first.copyWith(
          id: 'before-month',
          staffId: 'staff-03',
          startAt: DateTime.utc(2029, 12, 31, 16, 59),
          endAt: DateTime.utc(2029, 12, 31, 17),
          totalPriceVnd: 7000000,
        ),
        seeds.first.copyWith(
          id: 'other-revenue',
          branchId: 'branch-02',
          staffId: 'staff-05',
          totalPriceVnd: 900000,
        ),
        seeds.last.copyWith(
          id: 'other-upcoming',
          branchId: 'branch-02',
          staffId: 'staff-05',
          customerId: 'walk-in',
          customerName: 'Secret Guest',
        ),
      ],
    );
    users = UserProvider(
      rawUsers,
      auth: authentication,
      branchName: (id) => branches.getById(id)?.name,
      access: scope,
      canReadCustomer: (id, actor) => appointments.getAll().any(
        (a) => a.customerId == id && a.branchId == actor.branchId,
      ),
    );
    services = ServiceProvider(MockServiceRepository(), access: scope);
    settings = ShopSettingsProvider(access: scope);
    booking = AppointmentProvider(
      appointments,
      users: users,
      services: services,
      shopSettings: settings,
      access: scope,
      clock: () => DateTime.utc(2030, 1, 2, 3),
    );
    branches = BranchProvider(
      MockBranchRepository(),
      access: scope,
      users: rawUsers,
      appointments: appointments,
      settings: settings,
    );
  });
  tearDown(() {
    branches.dispose();
    booking.dispose();
    services.dispose();
    users.dispose();
    settings.dispose();
    scope.dispose();
    auth.dispose();
    rawUsers.dispose();
  });

  testWidgets(
    'Manager workspace isolates branches, hides catalog writes and binds walk-in',
    (tester) async {
      await tester.runAsync(
        () => auth.signIn(email: 'admin@example.com', password: 'admin123'),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: users),
            ChangeNotifierProvider.value(value: services),
            ChangeNotifierProvider.value(value: booking),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: branches),
          ],
          child: const MaterialApp(home: ManagerMain()),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tổng quan - Cơ sở Cầu Giấy'), findsOneWidget);
      expect(find.text('150.000đ'), findsOneWidget);
      expect(find.text('2 lịch'), findsOneWidget);
      expect(find.text('900.000đ'), findsNothing);
      await tester.ensureVisible(find.text('Customer Demo - Combo Cắt + Gội'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Secret Guest'), findsNothing);
      await tester.tap(find.byIcon(Icons.spa_outlined).last);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Thêm dịch vụ'), findsNothing);
      expect(find.byIcon(Icons.edit), findsNothing);
      expect(find.byIcon(Icons.delete), findsNothing);
      expect(
        () => services.delete(services.services.first.id),
        throwsA(isA<UnauthorizedException>()),
      );
      await tester.tap(find.byIcon(Icons.badge_outlined).last);
      await tester.pumpAndSettle();
      expect(find.text('Nguyễn Minh Hùng'), findsOneWidget);
      expect(find.text('Phạm Gia An'), findsNothing);
      expect(find.text('Trần Ngọc Linh'), findsNothing);
      await tester.tap(find.byIcon(Icons.dashboard_outlined));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Tạo lịch nhanh'));
      await tester.tap(find.text('Tạo lịch nhanh'));
      await tester.pumpAndSettle();
      final branchField = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>).first,
      );
      expect(branchField.initialValue, 'branch-01');
      expect(branchField.onChanged, isNull);
      Navigator.of(
        tester.element(find.byType(DropdownButtonFormField<String>).first),
      ).pop();
      await tester.pumpAndSettle();
      await tester.runAsync(
        () =>
            auth.signIn(email: 'manager2@example.com', password: 'manager123'),
      );
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(SingleChildScrollView).first,
        const Offset(0, 1000),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tổng quan - Cơ sở Đống Đa'), findsOneWidget);
      expect(find.text('900.000đ'), findsOneWidget);
      expect(find.text('150.000đ'), findsNothing);
      expect(find.text('2 lịch'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('Revenue reports isolate branches and include hidden completed rows at Vietnam boundaries', () async {
    await auth.signIn(email: 'admin@example.com', password: 'admin123');
    expect(
      booking.completedTransactions().fold<int>(
        0,
        (sum, a) => sum + a.totalPriceVnd,
      ),
      150000,
    );
    expect(
      booking
          .completedTransactions(month: true)
          .fold<int>(0, (sum, a) => sum + a.totalPriceVnd),
      450000,
    );
    expect(booking.monthlyStaffRevenue().first, (
      staffId: 'staff-03',
      completedCount: 1,
      revenueVnd: 300000,
    ));
    expect(
      () => booking.completedTransactions(branchId: 'branch-02'),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(
      () => booking.monthlyStaffRevenue(branchId: 'branch-02'),
      throwsA(isA<UnauthorizedException>()),
    );
    booking.updateStaffStatus(
      'appointment-demo-confirmed',
      AppointmentStatus.completed,
    );
    expect(booking.completedTransactions(), hasLength(2));
    await auth.signIn(email: 'manager2@example.com', password: 'manager123');
    expect(booking.completedTransactions().single.totalPriceVnd, 900000);
    expect(booking.monthlyStaffRevenue().single.staffId, 'staff-05');
    await auth.signIn(email: 'customer@example.com', password: 'customer123');
    expect(
      () => booking.completedTransactions(),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('Leave requests are branch scoped, decisions preserved and approved days block booking', () async {
    await auth.signIn(email: 'staff@exampler.com', password: 'staff123');
    users.requestDayOff(
      DateTime.utc(2030, 1, 3),
      expectedUserId: auth.currentUser!.id,
    );
    final first = users.leaveRequests.single;
    await auth.signIn(email: 'an@example.com', password: 'staff123');
    users.requestDayOff(
      DateTime.utc(2030, 1, 4),
      expectedUserId: auth.currentUser!.id,
    );
    final other = users.leaveRequests.single;
    await auth.signIn(email: 'admin@example.com', password: 'admin123');
    expect(users.leaveRequests.single.id, first.id);
    expect(
      () => users.reviewLeave(
        other.id,
        approved: true,
        expectedManagerId: auth.currentUser!.id,
      ),
      throwsA(isA<UnauthorizedException>()),
    );
    users.reviewLeave(
      first.id,
      approved: true,
      expectedManagerId: auth.currentUser!.id,
      note: 'Đã thống nhất',
    );
    expect(users.leaveRequests.single.status, LeaveStatus.approved);
    expect(users.leaveRequests.single.reviewedBy, 'admin-01');
    expect(users.leaveRequests.single.reviewedByName, 'Manager Demo');
    expect(users.leaveRequests.single.reviewedBranchName, 'Cơ sở Cầu Giấy');
    users.updateOwnProfile(
      expectedUserId: auth.currentUser!.id,
      name: 'Changed After Decision',
      email: 'admin@example.com',
      phone: '',
      address: '',
    );
    expect(users.leaveRequests.single.reviewedByName, 'Manager Demo');
    expect(users.leaveRequests.single.reviewedAt, isNotNull);
    expect(
      () => users.reviewLeave(
        first.id,
        approved: false,
        expectedManagerId: auth.currentUser!.id,
      ),
      throwsStateError,
    );
    await auth.signIn(email: 'boss@example.com', password: 'boss123');
    branches.update(
      branches.getById('branch-01')!.copyWith(name: 'Renamed Branch'),
    );
    expect(
      users.leaveRequests
          .singleWhere((r) => r.id == first.id)
          .reviewedBranchName,
      'Cơ sở Cầu Giấy',
    );
    await auth.signIn(email: 'customer@example.com', password: 'customer123');
    expect(
      booking.availableSlots(
        staffId: 'staff-01',
        serviceId: 'service-01',
        branchId: 'branch-01',
        date: DateTime.utc(2030, 1, 3),
      ),
      isEmpty,
    );
    expect(
      booking.availableSlots(
        staffId: 'staff-05',
        serviceId: 'service-02',
        branchId: 'branch-02',
        date: DateTime.utc(2030, 1, 4),
      ),
      isNotEmpty,
    );
    expect(() => users.leaveRequests, throwsA(isA<UnauthorizedException>()));
    await auth.signIn(email: 'manager2@example.com', password: 'manager123');
    users.reviewLeave(
      other.id,
      approved: false,
      expectedManagerId: auth.currentUser!.id,
      note: 'Thiếu nhân sự',
    );
    expect(users.leaveRequests.single.note, 'Thiếu nhân sự');
    await auth.signIn(email: 'an@example.com', password: 'staff123');
    users.requestDayOff(
      DateTime.utc(2030, 1, 4),
      expectedUserId: auth.currentUser!.id,
    );
    expect(users.leaveRequests, hasLength(2));
    expect(
      users.leaveRequests.where((r) => r.status == LeaveStatus.rejected),
      hasLength(1),
    );
  });

  testWidgets(
    'Manager settings edit own profile/password and staff tab approves with history',
    (tester) async {
      await tester.runAsync(
        () => auth.signIn(email: 'staff@exampler.com', password: 'staff123'),
      );
      users.requestDayOff(
        DateTime.utc(2030, 1, 3),
        expectedUserId: auth.currentUser!.id,
      );
      await tester.runAsync(
        () => auth.signIn(email: 'admin@example.com', password: 'admin123'),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: users),
            ChangeNotifierProvider.value(value: services),
            ChangeNotifierProvider.value(value: booking),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: branches),
          ],
          child: MaterialApp(
            home: const ManagerMain(),
            onGenerateRoute: AppRouter.generateRoute,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Thông tin cá nhân'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byType(TextFormField).at(0),
        'Manager Updated',
      );
      await tester.enterText(
        find.byType(TextFormField).at(1),
        'manager.updated@example.com',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(auth.currentUser!.name, 'Manager Updated');
      expect(auth.currentUser!.branchId, 'branch-01');
      await tester.tap(find.text('Đổi mật khẩu'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(0), 'admin123');
      await tester.enterText(find.byType(TextFormField).at(1), 'updated123');
      await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
      await tester.pumpAndSettle();
      expect(
        authentication.signIn(
          email: 'manager.updated@example.com',
          password: 'admin123',
        ),
        isNull,
      );
      expect(
        authentication
            .signIn(
              email: 'manager.updated@example.com',
              password: 'updated123',
            )!
            .id,
        'admin-01',
      );
      ScaffoldMessenger.of(tester.element(find.byType(ManagerMain)))
          .clearSnackBars();
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.badge_outlined).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Duyệt nghỉ'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Đồng ý nghỉ');
      await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
      await tester.pumpAndSettle();
      expect(find.text('Xin nghỉ phép (0 chờ duyệt)'), findsOneWidget);
      await tester.tap(find.text('Lịch sử phê duyệt (1)'));
      await tester.pumpAndSettle();
      expect(find.text('Ghi chú: Đồng ý nghỉ'), findsOneWidget);
      expect(
        find.text('Người xử lý: Manager Updated · Cơ sở Cầu Giấy'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Revenue CTA, period selector, today ledger and monthly ranking react without crossing branch',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(
        () => auth.signIn(email: 'admin@example.com', password: 'admin123'),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: users),
            ChangeNotifierProvider.value(value: services),
            ChangeNotifierProvider.value(value: booking),
            ChangeNotifierProvider.value(value: settings),
            ChangeNotifierProvider.value(value: branches),
          ],
          child: MaterialApp(
            home: const ManagerMain(),
            onGenerateRoute: AppRouter.generateRoute,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thợ rảnh'), findsNothing);
      expect(find.text('Lịch đã hủy'), findsOneWidget);
      await tester.ensureVisible(find.text('Báo cáo Doanh số'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Báo cáo Doanh số'));
      await tester.pumpAndSettle();
      expect(find.byType(ManagerRevenueScreen), findsOneWidget);
      expect(find.text('Cơ sở Cầu Giấy'), findsOneWidget);
      expect(find.text('150.000đ'), findsWidgets);
      expect(find.text('900.000đ'), findsNothing);
      await tester.tap(find.widgetWithText(ChoiceChip, 'Tháng này'));
      await tester.pumpAndSettle();
      expect(find.text('450.000đ'), findsOneWidget);
      await tester.ensureVisible(find.text('Thợ: Nguyễn Minh Hùng'));
      await tester.pumpAndSettle();
      expect(find.text('Customer Demo'), findsOneWidget);
      expect(find.text('1. Alex Nguyễn'), findsOneWidget);
      booking.updateStaffStatus(
        'appointment-demo-confirmed',
        AppointmentStatus.completed,
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView).first, const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(find.text('600.000đ'), findsOneWidget);
      await tester.runAsync(
        () =>
            auth.signIn(email: 'manager2@example.com', password: 'manager123'),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cơ sở Đống Đa'), findsOneWidget);
      expect(find.text('900.000đ'), findsWidgets);
      expect(find.text('600.000đ'), findsNothing);
      Navigator.of(tester.element(find.byType(ManagerRevenueScreen)))
          .pushNamedAndRemoveUntil(AppRoutes.managerDashboard, (_) => false);
      await tester.pumpAndSettle();
      expect(find.byType(ManagerMain), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('Recruitment uses session branch, reserves email and creates no credential; settings remain isolated', () async {
    await auth.signIn(email: 'admin@example.com', password: 'admin123');
    final profile = users.createStaffProfile(
      name: ' New Staff ',
      email: ' NEW@EXAMPLE.COM ',
      phone: '0901234567',
      address: 'Hà Nội',
      specializedCategoryIds: ['haircut'],
    );
    expect(profile.branchId, 'branch-01');
    expect(profile.isApproved, isFalse);
    expect(
      authentication.signIn(email: profile.email, password: 'anything'),
      isNull,
    );
    expect(
      booking.availableSlots(
        branchId: 'branch-01',
        staffId: profile.id,
        serviceId: 'service-01',
        date: booking.today,
      ),
      isEmpty,
    );
    expect(
      () => users.update(profile.copyWith(isApproved: true)),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(
      () => users.getStaff(branchId: 'branch-02'),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(
      () => users.createStaffProfile(
        name: 'Invalid',
        email: 'invalid@example.com',
        phone: '',
        address: 'Hà Nội',
        specializedCategoryIds: ['haircut'],
      ),
      throwsArgumentError,
    );
    settings.updateWorkingHours(
      const TimeOfDay(hour: 10, minute: 0),
      const TimeOfDay(hour: 19, minute: 0),
    );
    settings.addClosedDate(DateTime.utc(2030, 1, 3));
    expect(
      () => settings.updateWorkingHours(
        const TimeOfDay(hour: 10, minute: 0),
        const TimeOfDay(hour: 19, minute: 0),
        branchId: 'branch-02',
      ),
      throwsA(isA<UnauthorizedException>()),
    );
    await auth.signIn(email: 'manager2@example.com', password: 'manager123');
    expect(settings.settings.openingMinute, 540);
    expect(settings.settings.closedDates, isEmpty);
    expect(
      () => users.createStaffProfile(
        name: 'Duplicate',
        email: 'new@example.com',
        phone: '0901234567',
        address: 'Hà Nội',
        specializedCategoryIds: ['haircut'],
      ),
      throwsStateError,
    );
    expect(
      () => users.getById(profile.id),
      throwsA(isA<UnauthorizedException>()),
    );
    await auth.signIn(email: 'customer@example.com', password: 'customer123');
    expect(
      () => users.createStaffProfile(
        name: 'Forbidden',
        email: 'forbidden@example.com',
        phone: '0901234567',
        address: 'Hà Nội',
        specializedCategoryIds: ['haircut'],
      ),
      throwsA(isA<UnauthorizedException>()),
    );
  });
}
