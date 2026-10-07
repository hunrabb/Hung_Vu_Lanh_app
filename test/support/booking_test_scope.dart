import 'test_access.dart';

import 'package:ktgk/core/security/access_scope.dart';

import 'customer_fixture.dart';

import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/branches/application/branch_provider.dart';
import 'package:ktgk/features/branches/data/mock_branch_repository.dart';

import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/models/appointment.dart';
import 'package:ktgk/features/settings/application/shop_settings_provider.dart';
import 'package:ktgk/features/booking/application/appointment_provider.dart';
import 'package:ktgk/features/booking/data/mock_appointment_repository.dart';
import 'package:ktgk/features/catalog/application/service_provider.dart';
import 'package:ktgk/features/catalog/data/mock_service_repository.dart';
import 'package:ktgk/features/users/application/user_provider.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';

class BookingTestScope extends StatelessWidget {
  const BookingTestScope({
    super.key,
    required this.child,
    this.empty = false,
    this.manager = false,
    this.access,
  });
  final bool manager;
  final AccessScope? access;
  final Widget child;
  final bool empty;
  @override
  Widget build(BuildContext context) => MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthController>(
        create: (_) => customerFixtureAuth(manager: manager),
      ),
      ChangeNotifierProvider(
        create: (_) => ServiceProvider(
          MockServiceRepository(),
          access: access ?? testAccess(),
        ),
      ),
      ChangeNotifierProvider(
        create: (_) =>
            UserProvider(MockUserRepository(), access: access ?? testAccess()),
      ),
      ChangeNotifierProvider(
        create: (_) => ShopSettingsProvider(access: access ?? testAccess()),
      ),
      ChangeNotifierProvider(
        create: (context) => AppointmentProvider(
          MockAppointmentRepository(
            initialData: empty
                ? []
                : [
                    Appointment(
                      branchId: 'branch-01',
                      id: 'home-test',
                      customerId: 'customer-01',
                      staffId: 'staff-01',
                      serviceIds: ['service-01'],
                      serviceNamesSnapshot: ['Combo Cắt + Gội'],
                      startAt: DateTime.utc(2030, 1, 1, 2),
                      endAt: DateTime.utc(2030, 1, 1, 3),
                      totalPriceVnd: 150000,
                      status: AppointmentStatus.confirmed,
                    ),
                  ],
          ),
          services: context.read<ServiceProvider>(),
          users: context.read<UserProvider>(),
          shopSettings: context.read<ShopSettingsProvider>(),
          access: access ?? testAccess(),
        ),
      ),
      ChangeNotifierProvider(
        create: (context) => BranchProvider(
          MockBranchRepository(),
          access: access ?? testAccess(),
          users: MockUserRepository(),
          appointments: MockAppointmentRepository(initialData: []),
          settings: context.read<ShopSettingsProvider>(),
        ),
      ),
    ],
    child: child,
  );
}
