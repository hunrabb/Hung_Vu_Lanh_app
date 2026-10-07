import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktgk/app.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/schedule/presentation/staff_main.dart';
import 'package:ktgk/features/manager/presentation/manager_main.dart';
import 'package:provider/provider.dart';

void main() {
  for (final role in ['staff', 'admin']) {
    testWidgets('$role login opens correct shell, switches tabs and logs out', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 760);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const BarbershopApp(useMock: true));
      final fields = find.byType(TextFormField);
      await tester.enterText(
        fields.at(0),
        role == 'staff' ? 'staff@exampler.com' : 'admin@example.com',
      );
      await tester.enterText(fields.at(1), '${role}123');
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Login'));
      await tester.tap(find.widgetWithText(FilledButton, 'Login'));
      await tester.pumpAndSettle();
      final staff = role == 'staff';
      expect(find.byType(staff ? StaffMain : ManagerMain), findsOneWidget);
      final navigation = find.byType(BottomNavigationBar);
      expect(tester.widget<BottomNavigationBar>(navigation).items.length, 4);
      expect(find.text('Đăng xuất'), findsNothing);
      final icons = staff
          ? [Icons.people_outline, Icons.person_outline]
          : [Icons.badge_outlined, Icons.spa_outlined, Icons.settings_outlined];
      final messages = staff
          ? ['Danh sách khách hàng của bạn', 'Thông tin hồ sơ nhân viên']
          : ['Quản lý Nhân viên', 'Quản lý Dịch vụ', 'Cài đặt cơ sở'];
      for (var i = 0; i < icons.length; i++) {
        await tester.tap(
          find.descendant(of: navigation, matching: find.byIcon(icons[i])),
        );
        await tester.pumpAndSettle();
        expect(find.text(messages[i]), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      final context = tester.element(
        find.byType(staff ? StaffMain : ManagerMain),
      );
      final auth = context.read<AuthController>();
      await tester.ensureVisible(find.text('Đăng xuất'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();
      expect(auth.currentUser, isNull);
      expect(find.text('Welcome Back'), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isFalse);
    });
  }
}
