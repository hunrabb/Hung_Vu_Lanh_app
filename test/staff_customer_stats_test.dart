import 'support/test_access.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:ktgk/core/models/appointment.dart';
import 'package:ktgk/core/models/shop_settings.dart';
import 'package:ktgk/features/booking/application/appointment_provider.dart';
import 'package:ktgk/features/booking/data/mock_appointment_repository.dart';
import 'package:ktgk/features/catalog/application/service_provider.dart';
import 'package:ktgk/features/catalog/data/mock_service_repository.dart';
import 'package:ktgk/features/users/application/user_provider.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';

void main() {
  test(
    'Completed-only LTV, latest visit, exact 30-day boundary and all sorts',
    () {
      final now = DateTime.utc(2030, 2, 1);
      Appointment item(
        String id,
        String customer,
        int days,
        int price, {
        String staff = 'staff-01',
        AppointmentStatus status = AppointmentStatus.completed,
      }) {
        final end = now.subtract(Duration(days: days));
        return Appointment(
          branchId: 'branch-01',
          id: id,
          customerId: customer,
          staffId: staff,
          serviceIds: ['s'],
          serviceNamesSnapshot: ['S'],
          startAt: end.subtract(const Duration(hours: 1)),
          endAt: end,
          totalPriceVnd: price,
          status: status,
          isHiddenByStaff: true,
          isHiddenByCustomer: true,
        );
      }

      final services = ServiceProvider(
        MockServiceRepository(),
        access: testAccess(),
      );
      final users = UserProvider(MockUserRepository(), access: testAccess());
      final provider = AppointmentProvider(
        MockAppointmentRepository(
          initialData: [
            item('a1', 'a', 30, 100),
            item('a2', 'a', 40, 200),
            item('b', 'b', 31, 1000),
            item('c', 'c', 1, 50),
            item('ignored', 'a', 0, 5000, status: AppointmentStatus.noShow),
            item('other', 'a', 0, 9000, staff: 'staff-02'),
          ],
        ),
        services: services,
        users: users,
        settings: ShopSettings(
          branchId: 'branch-01',
          openingMinute: 480,
          closingMinute: 1200,
        ),
        clock: () => now,
        access: testAccess(),
      );
      addTearDown(provider.dispose);
      addTearDown(services.dispose);
      addTearDown(users.dispose);
      final recent = provider.staffCustomerStats('staff-01');
      expect(recent.map((x) => x.customerId), ['c', 'a', 'b']);
      expect(recent[1].visits, 2);
      expect(recent[1].totalSpendingVnd, 300);
      expect(recent[1].isInactive, isFalse);
      expect(recent.last.isInactive, isTrue);
      expect(
        provider
            .staffCustomerStats('staff-01', sort: StaffCustomerSort.mostVisits)
            .first
            .customerId,
        'a',
      );
      expect(
        provider
            .staffCustomerStats(
              'staff-01',
              sort: StaffCustomerSort.highestSpending,
            )
            .first
            .customerId,
        'b',
      );
      expect(
        provider.staffCustomerStats('staff-02').single.totalSpendingVnd,
        9000,
      );
      expect(provider.staffCustomerStats('missing'), isEmpty);
    },
  );
}
