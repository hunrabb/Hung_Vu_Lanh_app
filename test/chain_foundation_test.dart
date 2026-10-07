import 'support/test_access.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktgk/app.dart';
import 'package:ktgk/core/models/app_user.dart';
import 'package:ktgk/core/models/branch.dart';
import 'package:ktgk/core/mock/chain_seed.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';
import 'package:ktgk/features/booking/data/mock_appointment_repository.dart';
import 'package:ktgk/features/settings/application/shop_settings_provider.dart';
import 'package:ktgk/features/boss/presentation/boss_main_screen.dart';
import 'package:ktgk/features/manager/presentation/manager_main.dart';

void main() {
  test('Branch and user fields round-trip, nullable copy clears and legacy staff is rejected', () {
    const branch = Branch(
      id: 'b',
      name: 'Branch',
      address: 'Address',
      phone: '090123',
    );
    expect(Branch.fromJson(branch.toJson()).copyWith(name: 'New').name, 'New');
    final customer = AppUser(
      id: 'c',
      name: 'C',
      email: 'c@example.com',
      role: UserRole.customer,
      createdAt: DateTime.utc(2030),
    );
    expect(customer.isApproved, isTrue);
    final staff = customer.copyWith(
      role: UserRole.staff,
      branchId: 'b',
      isApproved: false,
      phone: '0901',
      address: 'A',
    );
    final restored = AppUser.fromJson(staff.toJson());
    expect(restored.branchId, 'b');
    expect(restored.phone, '0901');
    expect(restored.isApproved, isFalse);
    expect(restored.copyWith(phone: null, address: null).phone, isNull);
    expect(
      () => AppUser.fromJson(staff.toJson()..remove('branchId')),
      throwsArgumentError,
    );
    expect(
      AppUser.fromJson(staff.toJson()..remove('isApproved')).isApproved,
      isFalse,
    );
  });

  test('Configured branch fixtures retain role, appointment and settings consistency', () {
    final users = MockUserRepository().getAll();
    final ids = ChainSeed.settings().map((s) => s.branchId).toSet();
    expect(ChainSeed.branches.map((b) => b.id), containsAll(ids));
    expect(ids, hasLength(2));
    expect(
      users.where((u) => u.role == UserRole.superAdmin).single.branchId,
      isNull,
    );
    expect(users.where((u) => u.role == UserRole.manager), hasLength(2));
    for (final id in ids) {
      final staff = users.where(
        (u) => u.role == UserRole.staff && u.branchId == id,
      );
      expect(staff.any((u) => u.isApproved), isTrue);
      expect(staff.any((u) => !u.isApproved), isTrue);
    }
    for (final a in MockAppointmentRepository().getAll()) {
      expect(a.branchId, users.firstWhere((u) => u.id == a.staffId).branchId);
    }
    final settings = ShopSettingsProvider(access: testAccess());
    addTearDown(settings.dispose);
    expect(settings.branchSettings.map((s) => s.branchId).toSet(), ids);
    expect(settings.getByBranchId('branch-02')!.openingMinute, 540);
  });

  test('Pending staff is blocked even if a credential exists', () {
    final users = MockUserRepository();
    final auth = MockAuthRepository(users: users);
    auth.addStaffCredentials(users.getById('staff-06')!, 'pendingpass');
    expect(
      auth.signIn(email: 'pending@example.com', password: 'pendingpass'),
      isNull,
    );
  });

  for (final boss in [true, false]) {
    testWidgets(
      '${boss ? 'Boss' : 'Manager'} logs into the correct foundation route',
      (tester) async {
        await tester.pumpWidget(const BarbershopApp(useMock: true));
        final fields = find.byType(TextFormField);
        await tester.enterText(
          fields.at(0),
          boss ? 'boss@example.com' : 'manager2@example.com',
        );
        await tester.enterText(fields.at(1), boss ? 'boss123' : 'manager123');
        await tester.ensureVisible(find.widgetWithText(FilledButton, 'Login'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Login'));
        await tester.pumpAndSettle();
        expect(
          find.byType(boss ? BossMainScreen : ManagerMain),
          findsOneWidget,
        );
        final context = tester.element(
          find.byType(boss ? BossMainScreen : ManagerMain),
        );
        expect(
          ModalRoute.of(context)?.settings.name,
          boss ? '/boss' : '/manager',
        );
        expect(tester.takeException(), isNull);
        Navigator.of(context).pushNamed(boss ? '/manager' : '/boss');
        await tester.pumpAndSettle();
        expect(
          find.byType(boss ? BossMainScreen : ManagerMain),
          findsOneWidget,
        );
        expect(
          tester.state<NavigatorState>(find.byType(Navigator)).canPop(),
          isFalse,
        );
      },
    );
  }
}
