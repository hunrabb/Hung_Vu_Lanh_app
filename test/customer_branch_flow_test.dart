import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/models/app_user.dart';
import 'package:ktgk/core/routing/app_router.dart';
import 'package:ktgk/core/routing/app_routes.dart';
import 'package:ktgk/core/security/access_scope.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';
import 'package:ktgk/features/users/application/user_provider.dart';
import 'package:ktgk/features/catalog/data/mock_service_repository.dart';
import 'package:ktgk/features/catalog/application/service_provider.dart';
import 'package:ktgk/features/booking/data/mock_appointment_repository.dart';
import 'package:ktgk/features/booking/application/appointment_provider.dart';
import 'package:ktgk/features/booking/presentation/customer_booking_screen.dart';
import 'package:ktgk/features/branches/data/mock_branch_repository.dart';
import 'package:ktgk/features/branches/application/branch_provider.dart';
import 'package:ktgk/features/settings/application/shop_settings_provider.dart';

void main() {
  late MockUserRepository rawUsers;
  late AuthController auth;
  late AccessScope access;
  late UserProvider users;
  late ServiceProvider services;
  late ShopSettingsProvider settings;
  late AppointmentProvider booking;
  late BranchProvider branches;
  AppUser? serverActor;
  setUp(() {
    rawUsers = MockUserRepository();
    auth = AuthController(MockAuthRepository(users: rawUsers));
    // Override used only to simulate a separate authorized Boss updating shared settings.
    serverActor = null;
    access = AccessScope(() => serverActor ?? auth.currentUser, changes: auth);
    final repo = MockAppointmentRepository(initialData: []);
    users = UserProvider(rawUsers, access: access);
    services = ServiceProvider(MockServiceRepository(), access: access);
    settings = ShopSettingsProvider(access: access);
    booking = AppointmentProvider(
      repo,
      users: users,
      services: services,
      shopSettings: settings,
      access: access,
      clock: () => DateTime.utc(2030),
    );
    branches = BranchProvider(
      MockBranchRepository(),
      access: access,
      users: rawUsers,
      appointments: repo,
      settings: settings,
    );
  });
  tearDown(() {
    branches.dispose();
    booking.dispose();
    users.dispose();
    services.dispose();
    settings.dispose();
    access.dispose();
    auth.dispose();
    rawUsers.dispose();
  });
  Future<void> start(WidgetTester tester, String route) async {
    await tester.runAsync(
      () => auth.register(
        name: 'New Customer',
        email: 'new-customer@example.com',
        password: 'pass',
      ),
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: auth),
          ChangeNotifierProvider.value(value: users),
          ChangeNotifierProvider.value(value: services),
          ChangeNotifierProvider.value(value: settings),
          ChangeNotifierProvider.value(value: booking),
          ChangeNotifierProvider.value(value: branches),
        ],
        child: MaterialApp(
          initialRoute: route,
          onGenerateRoute: AppRouter.generateRoute,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, int index, String text) async {
    final field = find.byType(DropdownButtonFormField<String>).at(index);
    await tester.ensureVisible(field);
    await tester.pumpAndSettle();
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Home scopes hours/closure and passes branch to Booking without changing profile',
    (tester) async {
      await start(tester, AppRoutes.customerHome);
      await select(tester, 0, 'Cơ sở Cầu Giấy');
      expect(find.text('Giờ hoạt động: 08:00 - 20:00'), findsOneWidget);
      await select(tester, 0, 'Cơ sở Đống Đa');
      expect(find.text('Giờ hoạt động: 09:00 - 18:00'), findsOneWidget);
      expect(auth.currentUser!.branchId, isNull);
      serverActor = rawUsers.getById('boss-01');
      settings.addClosedDate(booking.today, branchId: 'branch-01');
      serverActor = null;
      await tester.pumpAndSettle();
      expect(
        find.text('Hôm nay cửa hàng tạm nghỉ. Hẹn gặp lại bạn vào ngày mai!'),
        findsNothing,
      );
      serverActor = rawUsers.getById('boss-01');
      settings.addClosedDate(booking.today, branchId: 'branch-02');
      serverActor = null;
      await tester.pumpAndSettle();
      expect(
        find.text('Hôm nay cửa hàng tạm nghỉ. Hẹn gặp lại bạn vào ngày mai!'),
        findsOneWidget,
      );
      serverActor = rawUsers.getById('boss-01');
      settings.removeClosedDate(booking.today, branchId: 'branch-02');
      serverActor = null;
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('primary-booking')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('primary-booking')));
      await tester.pumpAndSettle();
      expect(find.byType(CustomerBookingScreen), findsOneWidget);
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(
              find.byType(DropdownButtonFormField<String>).first,
            )
            .initialValue,
        'branch-02',
      );
    },
  );

  testWidgets(
    'Branch required, changing it clears staff/time, booking uses actual session identity',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await start(tester, AppRoutes.booking);
      final fields = find.byType(DropdownButtonFormField<String>);
      expect(
        tester.widget<DropdownButtonFormField<String>>(fields.at(1)).onChanged,
        isNull,
      );
      await select(tester, 0, 'Cơ sở Cầu Giấy');
      await select(tester, 1, 'Gội đầu thư giãn · 30 phút');
      await select(tester, 2, 'Nguyễn Minh Hùng');
      await tester.ensureVisible(find.byType(ChoiceChip).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ChoiceChip).first);
      await tester.pumpAndSettle();
      await select(tester, 0, 'Cơ sở Đống Đa');
      expect(
        tester
            .widget<DropdownButtonFormField<String>>(fields.last)
            .initialValue,
        isNull,
      );
      expect(find.byType(ChoiceChip), findsNothing);
      await select(tester, 2, 'Phạm Gia An');
      expect(find.text('09:00 – 09:30'), findsOneWidget);
      await tester.ensureVisible(find.byType(ChoiceChip).first);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(ChoiceChip).first);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Xác nhận'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xác nhận'));
      await tester.pumpAndSettle();
      final item = booking.appointments.single;
      expect(item.branchId, 'branch-02');
      expect(item.staffId, 'staff-05');
      expect(item.customerId, auth.currentUser!.id);
      expect(item.customerId, isNot('customer-01'));
      expect(
        () => booking.book(
          branchId: 'branch-01',
          customerId: item.customerId,
          staffId: 'staff-05',
          serviceId: 'service-02',
          startAt: item.endAt,
        ),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(
        () => booking.book(
          branchId: 'branch-02',
          customerId: 'customer-01',
          staffId: 'staff-05',
          serviceId: 'service-02',
          startAt: item.endAt,
        ),
        throwsA(isA<UnauthorizedException>()),
      );
      Navigator.of(tester.element(find.byType(CustomerBookingScreen)))
          .pushNamedAndRemoveUntil(AppRoutes.customerHome, (_) => false);
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.byIcon(Icons.calendar_today_outlined),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cơ sở: Cơ sở Đống Đa'), findsOneWidget);
    },
  );
}
