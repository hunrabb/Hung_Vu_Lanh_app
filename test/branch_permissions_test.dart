import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktgk/core/models/app_user.dart';
import 'package:ktgk/core/models/appointment.dart';
import 'package:ktgk/core/models/branch.dart';
import 'package:ktgk/core/models/service.dart';
import 'package:ktgk/core/security/access_scope.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';
import 'package:ktgk/features/branches/application/branch_provider.dart';
import 'package:ktgk/features/branches/data/mock_branch_repository.dart';
import 'package:ktgk/core/mock/chain_seed.dart';
import 'package:ktgk/features/users/application/user_provider.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';
import 'package:ktgk/features/catalog/application/service_provider.dart';
import 'package:ktgk/features/catalog/data/mock_service_repository.dart';
import 'package:ktgk/features/booking/application/appointment_provider.dart';
import 'package:ktgk/features/booking/data/mock_appointment_repository.dart';
import 'package:ktgk/features/settings/application/shop_settings_provider.dart';

void main() {
  late MockUserRepository rawUsers;
  late MockAppointmentRepository rawAppointments;
  late AuthController auth;
  late AccessScope access;
  late UserProvider users;
  late ServiceProvider services;
  late ShopSettingsProvider settings;
  late AppointmentProvider appointments;
  late BranchProvider branches;
  setUp(() {
    rawUsers = MockUserRepository();
    rawUsers.add(
      AppUser(
        id: 'other-customer',
        name: 'Other',
        email: 'other@example.com',
        role: UserRole.customer,
        createdAt: DateTime.utc(2030),
      ),
    );
    final authRepo = MockAuthRepository(users: rawUsers);
    auth = AuthController(authRepo);
    access = AccessScope(() => auth.currentUser, changes: auth);
    final rawBranches = MockBranchRepository();
    Appointment item(
      String id,
      String branch,
      String staff,
      int hour,
      AppointmentStatus status,
      int price,
      String customer,
    ) => Appointment(
      id: id,
      branchId: branch,
      staffId: staff,
      customerId: customer,
      serviceIds: ['service-01'],
      serviceNamesSnapshot: ['Service'],
      startAt: DateTime.utc(2030, 1, 2, hour),
      endAt: DateTime.utc(2030, 1, 2, hour + 1),
      totalPriceVnd: price,
      status: status,
      isHiddenByCustomer: status == AppointmentStatus.completed,
      isHiddenByStaff: status == AppointmentStatus.completed,
    );
    rawAppointments = MockAppointmentRepository(
      initialData: [
        item(
          'a-confirmed',
          'branch-01',
          'staff-01',
          3,
          AppointmentStatus.confirmed,
          150000,
          'customer-01',
        ),
        item(
          'a-completed',
          'branch-01',
          'staff-01',
          1,
          AppointmentStatus.completed,
          150000,
          'customer-01',
        ),
        item(
          'b-confirmed',
          'branch-02',
          'staff-05',
          3,
          AppointmentStatus.confirmed,
          80000,
          'customer-01',
        ),
        item(
          'b-completed',
          'branch-02',
          'staff-05',
          1,
          AppointmentStatus.completed,
          80000,
          'other-customer',
        ),
      ],
    );
    users = UserProvider(
      rawUsers,
      auth: authRepo,
      access: access,
      canReadCustomer: (id, actor) => rawAppointments.getAll().any(
        (a) =>
            a.customerId == id &&
            a.branchId == actor.branchId &&
            (actor.role == UserRole.manager || a.staffId == actor.id),
      ),
    );
    services = ServiceProvider(MockServiceRepository(), access: access);
    settings = ShopSettingsProvider(
      access: access,
      branchExists: (id) => rawBranches.getById(id) != null,
    );
    appointments = AppointmentProvider(
      rawAppointments,
      services: services,
      users: users,
      shopSettings: settings,
      access: access,
      clock: () => DateTime.utc(2030),
    );
    branches = BranchProvider(
      rawBranches,
      access: access,
      users: rawUsers,
      appointments: rawAppointments,
      settings: settings,
    );
  });
  tearDown(() {
    branches.dispose();
    appointments.dispose();
    users.dispose();
    services.dispose();
    settings.dispose();
    access.dispose();
    auth.dispose();
    rawUsers.dispose();
  });
  Future<void> login(String email, String password) async =>
      expect(await auth.signIn(email: email, password: password), isTrue);
  final denied = throwsA(isA<UnauthorizedException>());

  test('Manager reads only own branch; all cross-branch staff queries and writes fail', () async {
    await login('admin@example.com', 'admin123');
    expect(users.getStaff().every((u) => u.branchId == 'branch-01'), isTrue);
    expect(() => users.getStaff(branchId: 'branch-02'), denied);
    expect(() => users.getById('staff-05'), denied);
    expect(
      () =>
          users.update(rawUsers.getById('staff-05')!.copyWith(name: 'Forged')),
      denied,
    );
    expect(() => users.delete('staff-05'), denied);
    final own = rawUsers.getById('staff-01')!;
    expect(() => users.update(own.copyWith(branchId: 'branch-02')), denied);
    expect(() => users.update(own.copyWith(role: UserRole.manager)), denied);
    expect(
      () => users.update(
        rawUsers.getById('staff-06')!.copyWith(isApproved: true),
      ),
      denied,
    );
    expect(
      () => users.createStaff(
        own.copyWith(id: 'new'),
        'pass',
        actor: rawUsers.getById('boss-01')!,
      ),
      denied,
    );
    users.update(own.copyWith(name: 'Updated'));
    expect(rawUsers.getById('staff-01')!.name, 'Updated');
    expect(rawUsers.getById('staff-05')!.name, 'Phạm Gia An');
  });

  test('Manager metrics are scoped; cancel/complete/noShow cannot touch another branch', () async {
    await login('admin@example.com', 'admin123');
    expect(appointments.appointments, hasLength(2));
    expect(appointments.revenue(), 150000);
    expect(appointments.countAppointments(), 2);
    expect(
      appointments.staffCustomerStats('staff-01').single.totalSpendingVnd,
      150000,
    );
    expect(() => appointments.revenue(branchId: 'branch-02'), denied);
    expect(() => appointments.getByStaffId('staff-05'), denied);
    expect(() => appointments.cancel('b-confirmed'), denied);
    for (final status in [
      AppointmentStatus.completed,
      AppointmentStatus.noShow,
    ]) {
      expect(
        () => appointments.updateStaffStatus('b-confirmed', status),
        denied,
      );
    }
    expect(
      rawAppointments.getByStaffId('staff-05').first.status,
      AppointmentStatus.confirmed,
    );
    appointments.updateStaffStatus('a-confirmed', AppointmentStatus.completed);
    expect(appointments.revenue(), 300000);
    await login('manager2@example.com', 'manager123');
    expect(appointments.revenue(), 80000);
    appointments.cancel('b-confirmed');
    expect(
      appointments.appointments.where(
        (a) => a.status == AppointmentStatus.cancelled,
      ),
      hasLength(1),
    );
  });

  test('Only Boss writes branches/catalog; deleting a referenced branch is blocked', () async {
    const branch = Branch(
      id: 'branch-test-new',
      name: 'New',
      address: 'Address',
      phone: '0903',
    );
    final service = Service(
      id: 'new-service',
      name: 'New',
      category: ServiceCategory.haircut,
      durationMinutes: 30,
      priceVnd: 100000,
    );
    for (final credentials in [
      ('admin@example.com', 'admin123'),
      ('staff@exampler.com', 'staff123'),
      ('customer@example.com', 'customer123'),
    ]) {
      await login(credentials.$1, credentials.$2);
      expect(
        branches.branches.map((b) => b.id).toSet(),
        ChainSeed.branches.map((b) => b.id).toSet(),
      );
      expect(services.services, isNotEmpty);
      expect(() => branches.add(branch), denied);
      expect(() => branches.update(branch), denied);
      expect(() => branches.delete('branch-01'), denied);
      expect(() => services.add(service), denied);
      expect(() => services.update(services.services.first), denied);
      expect(() => services.delete('service-01'), denied);
    }
    await login('boss@example.com', 'boss123');
    expect(appointments.appointments, hasLength(4));
    expect(appointments.revenue(), 230000);
    branches.add(branch);
    expect(settings.getSettings(branch.id).branchId, branch.id);
    branches.update(branch.copyWith(name: 'Edited'));
    branches.delete(branch.id);
    expect(branches.getById(branch.id), isNull);
    expect(() => branches.delete('branch-01'), throwsStateError);
    services.add(service);
    services.update(service.copyWith(priceVnd: 120000));
    expect(services.getById(service.id)!.priceVnd, 120000);
    services.delete(service.id);
  });

  test(
    'Settings per branch are independent and reject cross-branch read/write',
    () async {
      await login('admin@example.com', 'admin123');
      settings.updateWorkingHours(
        const TimeOfDay(hour: 7, minute: 0),
        const TimeOfDay(hour: 19, minute: 0),
      );
      expect(() => settings.getSettings('branch-02'), denied);
      expect(
        () => settings.updateWorkingHours(
          const TimeOfDay(hour: 8, minute: 0),
          const TimeOfDay(hour: 18, minute: 0),
          branchId: 'branch-02',
        ),
        denied,
      );
      settings.addClosedDate(DateTime.utc(2030, 1, 2));
      expect(
        () => settings.addClosedDate(
          DateTime.utc(2030, 1, 2),
          branchId: 'branch-02',
        ),
        denied,
      );
      await login('manager2@example.com', 'manager123');
      expect(settings.settings.openingMinute, 540);
      expect(settings.closedDates, isEmpty);
      await login('boss@example.com', 'boss123');
      expect(settings.getSettings('branch-01').openingMinute, 420);
      expect(settings.getSettings('branch-02').openingMinute, 540);
    },
  );

  test('Customer/Staff ownership is enforced; skill availability does not expose bookings', () async {
    rawUsers.update(
      rawUsers
          .getById('staff-01')!
          .copyWith(phone: 'private-phone', address: 'private-address'),
    );
    await login('customer@example.com', 'customer123');
    expect(users.getById('staff-01')!.email, isEmpty);
    expect(users.getById('staff-01')!.phone, isNull);
    expect(users.getById('staff-01')!.address, isNull);
    expect(appointments.appointments, hasLength(3));
    expect(() => appointments.getByCustomerId('other-customer'), denied);
    expect(() => appointments.cancel('b-completed'), denied);
    expect(
      () => appointments.updateStaffStatus(
        'a-confirmed',
        AppointmentStatus.completed,
      ),
      denied,
    );
    expect(
      () => appointments.book(
        customerId: 'other-customer',
        staffId: 'staff-01',
        serviceId: 'service-01',
        startAt: DateTime.utc(2030, 1, 2, 5),
      ),
      denied,
    );
    appointments.cancel('a-confirmed');
    await login('staff@exampler.com', 'staff123');
    expect(
      appointments.appointments.every((a) => a.staffId == 'staff-01'),
      isTrue,
    );
    expect(() => appointments.getByStaffId('staff-05'), denied);
    expect(() => appointments.hideAppointmentFromStaff('b-completed'), denied);
    expect(
      () => appointments.hideAppointmentFromCustomer('a-completed'),
      denied,
    );
  });

  test(
    'Live branch/approval changes revoke stale session privileges',
    () async {
      await login('admin@example.com', 'admin123');
      rawUsers.update(
        rawUsers.getById('admin-01')!.copyWith(branchId: 'branch-02'),
      );
      expect(auth.currentUser!.branchId, 'branch-02');
      expect(
        appointments.appointments.every((a) => a.branchId == 'branch-02'),
        isTrue,
      );
      expect(() => appointments.getAppointments(branchId: 'branch-01'), denied);
      await login('staff@exampler.com', 'staff123');
      rawUsers.update(
        rawUsers.getById('staff-01')!.copyWith(isApproved: false),
      );
      expect(auth.currentUser, isNull);
      expect(
        () => appointments.updateStaffStatus(
          'a-confirmed',
          AppointmentStatus.completed,
        ),
        denied,
      );
      auth.signOut();
      expect(() => services.delete('service-01'), denied);
    },
  );
}
