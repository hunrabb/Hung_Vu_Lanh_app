import 'support/test_access.dart';

import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/core/models/appointment.dart';
import 'package:ktgk/features/booking/data/mock_appointment_repository.dart';
import 'package:ktgk/features/booking/application/appointment_provider.dart';
import 'package:ktgk/core/models/shop_settings.dart';
import 'package:ktgk/features/catalog/application/service_provider.dart';
import 'package:ktgk/features/catalog/data/mock_service_repository.dart';
import 'package:ktgk/features/users/application/user_provider.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';
import 'package:ktgk/features/staff/presentation/staff_schedule_screen.dart';

void main() {
  test('Staff hide preserves Customer visibility and legacy JSON defaults', () {
    final repository = MockAppointmentRepository();
    final completed = repository.getAll().first;
    final legacy = completed.toJson()..remove('isHiddenByStaff');
    expect(Appointment.fromJson(legacy).isHiddenByStaff, isFalse);
    expect(repository.hideAppointmentFromStaff(completed.id), isTrue);
    expect(repository.hideAppointmentFromStaff(completed.id), isFalse);
    final hidden = repository.getByCustomerId('customer-01').first;
    expect(hidden.status, AppointmentStatus.completed);
    expect(hidden.isHiddenByCustomer, isFalse);
    expect(Appointment.fromJson(hidden.toJson()).isHiddenByStaff, isTrue);
    expect(hidden.copyWith(isHiddenByStaff: false).isHiddenByStaff, isFalse);
    expect(
      () => repository.hideAppointmentFromStaff('appointment-demo-confirmed'),
      throwsStateError,
    );
    expect(
      () => repository.hideAppointmentFromStaff('missing'),
      throwsStateError,
    );
  });

  testWidgets(
    'Completed shift moves to ended section and hide requires confirmation',
    (tester) async {
      final auth = AuthController(MockAuthRepository());
      addTearDown(auth.dispose);
      await tester.runAsync(
        () => auth.signIn(email: 'staff@exampler.com', password: 'staff123'),
      );
      final users = UserProvider(MockUserRepository(), access: testAccess());
      final services = ServiceProvider(
        MockServiceRepository(),
        access: testAccess(),
      );
      final provider = AppointmentProvider(
        MockAppointmentRepository(),
        users: users,
        services: services,
        settings: ShopSettings(
          branchId: 'branch-01',
          openingMinute: 480,
          closingMinute: 1200,
        ),
        access: testAccess(),
      );
      addTearDown(users.dispose);
      addTearDown(services.dispose);
      addTearDown(provider.dispose);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: users),
            ChangeNotifierProvider.value(value: provider),
          ],
          child: const MaterialApp(home: StaffScheduleScreen()),
        ),
      );
      expect(find.text('Ca sắp tới (1)'), findsOneWidget);
      expect(find.text('Ca đã kết thúc (1)'), findsOneWidget);
      final action = find.text('Hoàn thành ca');
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      await tester.tap(action);
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 1000));
      await tester.pumpAndSettle();
      expect(find.text('Ca sắp tới (0)'), findsOneWidget);
      expect(find.text('Ca đã kết thúc (2)'), findsOneWidget);
      final card = find.byKey(const ValueKey('appointment-demo-confirmed'));
      final hide = find.descendant(
        of: card,
        matching: find.byTooltip('Ẩn ca làm'),
      );
      await tester.ensureVisible(hide);
      await tester.pumpAndSettle();
      await tester.tap(hide);
      await tester.pumpAndSettle();
      expect(find.text('Ẩn ca làm này khỏi lịch trình?'), findsOneWidget);
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('appointment-demo-confirmed')),
        findsOneWidget,
      );
      await tester.tap(hide);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đồng ý'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('appointment-demo-confirmed')),
        findsNothing,
      );
      expect(provider.getByCustomerId('customer-01'), hasLength(2));
      expect(provider.appointments.last.isHiddenByStaff, isTrue);
      expect(provider.appointments.last.isHiddenByCustomer, isFalse);
    },
  );
}
