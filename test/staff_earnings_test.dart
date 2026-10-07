import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/models/appointment.dart';
import 'package:ktgk/core/security/access_scope.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';
import 'package:ktgk/features/users/application/user_provider.dart';
import 'package:ktgk/features/catalog/data/mock_service_repository.dart';
import 'package:ktgk/features/catalog/application/service_provider.dart';
import 'package:ktgk/features/booking/data/mock_appointment_repository.dart';
import 'package:ktgk/features/booking/application/appointment_provider.dart';
import 'package:ktgk/features/schedule/presentation/staff_main.dart';
import 'package:ktgk/features/staff/presentation/staff_profile_screen.dart';
import 'package:ktgk/core/routing/app_router.dart';
import 'package:ktgk/core/routing/app_routes.dart';

void main() {
  late MockUserRepository rawUsers;
  late AuthController auth;
  late AccessScope scope;
  late UserProvider users;
  late ServiceProvider services;
  late AppointmentProvider booking;
  setUp(() {
    rawUsers = MockUserRepository();
    final authentication = MockAuthRepository(users: rawUsers);
    auth = AuthController(authentication);
    scope = AccessScope(() => auth.currentUser, changes: auth);
    Appointment row(
      String id,
      DateTime date,
      int amount, {
      String staff = 'staff-05',
      String branch = 'branch-02',
      AppointmentStatus status = AppointmentStatus.completed,
      bool hidden = false,
    }) => Appointment(
      id: id,
      customerId: 'customer-01',
      staffId: staff,
      branchId: branch,
      serviceIds: ['service-02'],
      serviceNamesSnapshot: ['Dịch vụ $id'],
      startAt: date,
      endAt: date.add(const Duration(minutes: 1)),
      totalPriceVnd: amount,
      status: status,
      isHiddenByStaff: hidden,
      isHiddenByCustomer: hidden,
      isReviewed: ['today', 'month-start', 'cancelled'].contains(id),
      rating: id == 'today'
          ? 5
          : id == 'month-start'
          ? 3
          : id == 'cancelled'
          ? 1
          : null,
    );
    final repo = MockAppointmentRepository(
      initialData: [
        row('today', DateTime.utc(2030, 1, 2, 1), 100000, hidden: true),
        row('month-start', DateTime.utc(2029, 12, 31, 17), 200000),
        row('before-month', DateTime.utc(2029, 12, 31, 16, 59), 900000),
        row('next-month', DateTime.utc(2030, 1, 31, 17), 600000),
        row(
          'confirmed',
          DateTime.utc(2030, 1, 2, 3),
          50000,
          status: AppointmentStatus.confirmed,
        ),
        row(
          'cancelled',
          DateTime.utc(2030, 1, 2, 4),
          800000,
          status: AppointmentStatus.cancelled,
        ),
        row(
          'no-show',
          DateTime.utc(2030, 1, 2, 5),
          700000,
          status: AppointmentStatus.noShow,
        ),
        row(
          'other-staff',
          DateTime.utc(2030, 1, 2, 1),
          3000000,
          staff: 'staff-01',
          branch: 'branch-01',
        ),
        row(
          'old-branch',
          DateTime.utc(2030, 1, 1, 1),
          4000000,
          branch: 'branch-01',
        ),
      ],
    );
    users = UserProvider(
      rawUsers,
      auth: authentication,
      access: scope,
      canReadCustomer: (id, actor) => repo.getAll().any(
        (a) =>
            a.customerId == id &&
            a.staffId == actor.id &&
            a.branchId == actor.branchId,
      ),
    );
    services = ServiceProvider(MockServiceRepository(), access: scope);
    booking = AppointmentProvider(
      repo,
      users: users,
      services: services,
      access: scope,
      clock: () => DateTime.utc(2030, 1, 2, 6),
    );
  });
  tearDown(() {
    booking.dispose();
    services.dispose();
    users.dispose();
    scope.dispose();
    auth.dispose();
    rawUsers.dispose();
  });

  test('Own revenue respects session, period boundaries, statuses and hidden flags', () async {
    await auth.signIn(email: 'an@example.com', password: 'staff123');
    expect(
      booking.ownCompletedAppointments(month: false).single.totalPriceVnd,
      100000,
    );
    expect(
      booking
          .ownCompletedAppointments(month: true)
          .fold<int>(0, (sum, a) => sum + a.totalPriceVnd),
      300000,
    );
    expect(booking.ownCompletedAppointments(), hasLength(4));
    expect(booking.ownAverageRating, 4.0);
    expect(
      booking.ownCompletedAppointments().every(
        (a) => a.staffId == auth.currentUser!.id && a.branchId == 'branch-02',
      ),
      isTrue,
    );
    expect(
      () => booking.ownCompletedAppointments().clear(),
      throwsUnsupportedError,
    );
    booking.updateStaffStatus('confirmed', AppointmentStatus.completed);
    expect(
      booking
          .ownCompletedAppointments(month: false)
          .fold<int>(0, (sum, a) => sum + a.totalPriceVnd),
      150000,
    );
    booking.hideAppointmentFromStaff('confirmed');
    expect(booking.ownCompletedAppointments(month: false), hasLength(2));
    expect(
      () => booking.getByStaffId('staff-01'),
      throwsA(isA<UnauthorizedException>()),
    );
    await auth.signIn(email: 'boss@example.com', password: 'boss123');
    expect(
      () => booking.ownCompletedAppointments(),
      throwsA(isA<UnauthorizedException>()),
    );
    auth.signOut();
    expect(
      () => booking.ownCompletedAppointments(),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  test('Review JSON defaults, nullable copy and valid star range', () {
    final a = MockAppointmentRepository().getAll().first.copyWith(
      isReviewed: true,
      rating: 5,
    );
    expect(Appointment.fromJson(a.toJson()).rating, 5);
    expect(a.copyWith(isReviewed: false, rating: null).rating, isNull);
    final legacy = a.toJson()
      ..remove('rating')
      ..remove('isReviewed');
    expect(Appointment.fromJson(legacy).isReviewed, isFalse);
    final missingFlag = Appointment(
      id: a.id,
      branchId: a.branchId,
      customerId: a.customerId,
      staffId: a.staffId,
      serviceIds: a.serviceIds,
      serviceNamesSnapshot: a.serviceNamesSnapshot,
      startAt: a.startAt,
      endAt: a.endAt,
      totalPriceVnd: a.totalPriceVnd,
      isReviewed: null,
    );
    expect(missingFlag.isReviewed, isFalse);
    expect(missingFlag.toJson()['isReviewed'], isFalse);
    expect(missingFlag.copyWith().isReviewed, isFalse);
    expect(() => a.copyWith(rating: 0), throwsArgumentError);
    expect(() => a.copyWith(rating: null), throwsArgumentError);
  });

  test('Password change verifies old password; days off are scoped, immutable and deduplicated', () async {
    await auth.signIn(email: 'an@example.com', password: 'staff123');
    final id = auth.currentUser!.id;
    expect(
      () => users.changeOwnPassword('wrong', 'newpass', expectedUserId: id),
      throwsStateError,
    );
    users.changeOwnPassword('staff123', 'newpass', expectedUserId: id);
    expect(auth.currentUser!.id, id);
    users.requestDayOff(DateTime.utc(2040, 1, 1), expectedUserId: id);
    users.requestDayOff(DateTime.utc(2040, 1, 1), expectedUserId: id);
    expect(users.ownDayOffs, ['2040-01-01']);
    expect(() => users.ownDayOffs.clear(), throwsUnsupportedError);
    expect(
      () => users.requestDayOff(DateTime.utc(2000), expectedUserId: id),
      throwsArgumentError,
    );
    expect(
      await auth.signIn(email: 'an@example.com', password: 'staff123'),
      isFalse,
    );
    expect(
      await auth.signIn(email: 'an@example.com', password: 'newpass'),
      isTrue,
    );
    await auth.signIn(email: 'staff@exampler.com', password: 'staff123');
    expect(booking.ownAverageRating, isNull);
    expect(users.ownDayOffs, isEmpty);
    expect(
      () => users.changeOwnPassword('newpass', 'hijacked', expectedUserId: id),
      throwsA(isA<UnauthorizedException>()),
    );
    expect(
      () => users.requestDayOff(DateTime.utc(2040, 1, 1), expectedUserId: id),
      throwsA(isA<UnauthorizedException>()),
    );
  });

  testWidgets('Dynamic profile, password form, leave date and logout', (
    tester,
  ) async {
    await tester.runAsync(
      () => auth.signIn(email: 'an@example.com', password: 'staff123'),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: users),
          ChangeNotifierProvider.value(value: booking),
        ],
        child: MaterialApp(
          initialRoute: AppRoutes.staffSchedule,
          onGenerateRoute: AppRouter.generateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BottomNavigationBar),
        matching: find.byIcon(Icons.person_outline),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Phạm Gia An'), findsOneWidget);
    expect(find.text('Chuyên môn: Gội đầu'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('4.0'), findsOneWidget);
    await tester.tap(find.text('Đổi mật khẩu'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'wrong');
    await tester.enterText(find.byType(TextFormField).at(1), 'changed123');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Mật khẩu cũ không đúng.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'staff123');
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    await tester.tap(find.text('Xin nghỉ phép'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(users.ownDayOffs, hasLength(1));
    ScaffoldMessenger.of(tester.element(find.byType(StaffProfileScreen)))
        .clearSnackBars();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Đăng xuất'),
      250,
      scrollable: find
          .descendant(
            of: find.byType(StaffProfileScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(auth.currentUser, isNull);
    expect(find.text('Welcome Back'), findsOneWidget);
    expect(
      tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
      isFalse,
    );
    expect(
      await tester.runAsync(
        () => auth.signIn(email: 'an@example.com', password: 'changed123'),
      ),
      isTrue,
    );
  });

  testWidgets(
    'Four Staff tabs, own summary, completed history and live completion on small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.runAsync(
        () => auth.signIn(email: 'an@example.com', password: 'staff123'),
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: users),
            ChangeNotifierProvider.value(value: booking),
          ],
          child: const MaterialApp(home: StaffMain()),
        ),
      );
      await tester.pumpAndSettle();
      final nav = find.byType(BottomNavigationBar);
      expect(tester.widget<BottomNavigationBar>(nav).items.length, 4);
      await tester.tap(
        find.descendant(
          of: nav,
          matching: find.byIcon(Icons.payments_outlined),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Thu nhập của tôi'), findsOneWidget);
      expect(find.text('100.000đ'), findsOneWidget);
      expect(find.text('300.000đ'), findsOneWidget);
      expect(find.text('Dịch vụ other-staff'), findsNothing);
      expect(find.text('Dịch vụ cancelled'), findsNothing);
      booking.updateStaffStatus('confirmed', AppointmentStatus.completed);
      await tester.pumpAndSettle();
      expect(find.text('150.000đ'), findsOneWidget);
      expect(find.text('350.000đ'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Dịch vụ today'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(find.text('Customer Demo'), findsWidgets);
      expect(find.text('Doanh số: 100.000đ'), findsOneWidget);
      await tester.tap(
        find.descendant(of: nav, matching: find.byIcon(Icons.people_outline)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Doanh số cá nhân'), findsOneWidget);
      expect(find.text('350.000đ'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
