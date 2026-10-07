import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktgk/app.dart';
import 'package:ktgk/core/models/app_user.dart';
import 'package:ktgk/core/models/appointment.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';
import 'package:ktgk/features/booking/data/mock_appointment_repository.dart';

void main() {
  test('Auth, selectable staff and today appointment seeds share identity', () {
    final staff = MockUserRepository().getById('staff-01')!;
    final login = MockAuthRepository().signIn(
      email: 'staff@exampler.com',
      password: 'staff123',
    )!;
    expect(staff.role, UserRole.staff);
    expect(staff.email, login.email);
    expect(staff.id, login.id);
    expect(staff.name, login.name);
    // UTC date differs from Vietnam date here; seeds must follow Vietnam.
    final now = DateTime.utc(2030, 1, 1, 20);
    final repo = MockAppointmentRepository(now: now);
    final appointments = repo.getByStaffId(staff.id);
    expect(appointments, hasLength(2));
    expect(
      appointments.map((a) => a.status),
      containsAll([AppointmentStatus.confirmed, AppointmentStatus.completed]),
    );
    for (final item in appointments) {
      expect(item.customerId, 'customer-01');
      expect(item.startAt.add(const Duration(hours: 7)).day, 2);
      expect(item.startAt.isUtc, isTrue);
    }
    expect(MockAppointmentRepository(initialData: []).getAll(), isEmpty);
  });

  testWidgets(
    'Staff login immediately sees seeded schedule and customer visits',
    (tester) async {
      await tester.pumpWidget(const BarbershopApp(useMock: true));
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'staff@exampler.com');
      await tester.enterText(fields.at(1), 'staff123');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Login'));
      await tester.tap(find.widgetWithText(FilledButton, 'Login'));
      await tester.pumpAndSettle();
      expect(find.text('Đã xác nhận'), findsOneWidget);
      expect(find.text('Đã hoàn thành'), findsOneWidget);
      expect(find.text('Combo Cắt + Gội'), findsNWidgets(2));
      await tester.tap(
        find.descendant(
          of: find.byType(BottomNavigationBar),
          matching: find.byIcon(Icons.people_outline),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Customer Demo'), findsOneWidget);
      expect(find.text('1 lần'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
