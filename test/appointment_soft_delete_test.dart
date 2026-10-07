import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/models/appointment.dart';
import 'package:ktgk/features/booking/data/mock_appointment_repository.dart';
import 'package:ktgk/features/booking/application/appointment_provider.dart';
import 'package:ktgk/features/customer/presentation/customer_appointments_screen.dart';

import 'support/booking_test_scope.dart';

void main() {
  Appointment item(AppointmentStatus status) => Appointment(
    branchId: 'branch-01',
    id: status.name,
    customerId: 'customer-01',
    staffId: 'staff-01',
    serviceIds: ['service-01'],
    serviceNamesSnapshot: ['Test service'],
    startAt: DateTime.utc(2030, 1, 1),
    endAt: DateTime.utc(2030, 1, 1, 1),
    totalPriceVnd: 100000,
    status: status,
  );

  test(
    'Hidden flag serializes and supports legacy JSON; repository retains stats',
    () {
      for (final status in [
        AppointmentStatus.completed,
        AppointmentStatus.cancelled,
        AppointmentStatus.noShow,
      ]) {
        final original = item(status);
        final legacy = original.toJson()..remove('isHiddenByCustomer');
        expect(Appointment.fromJson(legacy).isHiddenByCustomer, isFalse);
        final repository = MockAppointmentRepository(initialData: [original]);
        expect(repository.hideAppointmentFromCustomer(original.id), isTrue);
        expect(repository.hideAppointmentFromCustomer(original.id), isFalse);
        final hidden = repository.getByStaffId('staff-01').single;
        expect(hidden.isHiddenByCustomer, isTrue);
        expect(hidden.status, status);
        expect(hidden.totalPriceVnd, 100000);
        expect(repository.getByCustomerId('customer-01'), hasLength(1));
        expect(
          Appointment.fromJson(hidden.toJson()).isHiddenByCustomer,
          isTrue,
        );
        expect(
          hidden.copyWith(isHiddenByCustomer: false).isHiddenByCustomer,
          isFalse,
        );
      }
      final repository = MockAppointmentRepository(
        initialData: [item(AppointmentStatus.confirmed)],
      );
      expect(
        () => repository.hideAppointmentFromCustomer('confirmed'),
        throwsStateError,
      );
      expect(
        () => repository.hideAppointmentFromCustomer('missing'),
        throwsStateError,
      );
    },
  );

  testWidgets(
    'History delete requires confirmation and only hides retained data',
    (tester) async {
      await tester.pumpWidget(
        const BookingTestScope(
          child: MaterialApp(
            home: Scaffold(body: CustomerAppointmentsScreen()),
          ),
        ),
      );
      final provider = tester
          .element(find.byType(CustomerAppointmentsScreen))
          .read<AppointmentProvider>();
      expect(find.byTooltip('Xóa lịch sử'), findsNothing);
      provider.cancel('home-test');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Xóa lịch sử'));
      await tester.pumpAndSettle();
      expect(
        find.text('Bạn có chắc chắn muốn xóa lịch sử này không?'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
      await tester.pumpAndSettle();
      expect(provider.appointments.single.isHiddenByCustomer, isFalse);
      await tester.tap(find.byTooltip('Xóa lịch sử'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Đồng ý'));
      await tester.pumpAndSettle();
      expect(find.text('Bạn chưa có lịch hẹn nào'), findsOneWidget);
      expect(provider.appointments, hasLength(1));
      expect(
        provider.getByStaffId('staff-01').single.isHiddenByCustomer,
        isTrue,
      );
      expect(provider.appointments.single.status, AppointmentStatus.cancelled);
    },
  );
}
