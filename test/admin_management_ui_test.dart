import 'support/test_access.dart';
import 'support/booking_test_scope.dart';

import 'package:ktgk/features/catalog/presentation/service_catalog_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ktgk/features/auth/application/auth_controller.dart';
import 'package:ktgk/features/auth/data/mock_auth_repository.dart';
import 'package:ktgk/core/models/app_user.dart';
import 'package:ktgk/features/catalog/application/service_provider.dart';
import 'package:ktgk/features/catalog/data/mock_service_repository.dart';
import 'package:ktgk/features/users/application/user_provider.dart';
import 'package:ktgk/features/users/data/mock_user_repository.dart';
import 'package:ktgk/features/manager/presentation/manager_staff_screen.dart';

void main() {
  for (final isService in [true]) {
    testWidgets(
      '${isService ? 'Service' : 'Staff'} validates, adds, edits and deletes on small phone',
      (tester) async {
        tester.view.physicalSize = const Size(320, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final services = ServiceProvider(
          MockServiceRepository(initialData: isService ? [] : null),
          access: testAccess(),
        );
        final users = UserProvider(
          MockUserRepository(initialData: []),
          access: testAccess(),
        );
        final auth = AuthController(MockAuthRepository());
        addTearDown(auth.dispose);
        await tester.runAsync(
          () => auth.signIn(email: 'boss@example.com', password: 'boss123'),
        );
        addTearDown(services.dispose);
        addTearDown(users.dispose);
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: services),
              ChangeNotifierProvider.value(value: users),
              ChangeNotifierProvider.value(value: auth),
            ],
            child: MaterialApp(
              home: isService
                  ? const ServiceCatalogScreen(readOnly: false)
                  : const ManagerStaffScreen(),
            ),
          ),
        );
        await tester.tap(
          find.byTooltip(isService ? 'Thêm dịch vụ' : 'Thêm nhân viên'),
        );
        await tester.pumpAndSettle();
        Future<void> save() async {
          await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
          await tester.pumpAndSettle();
        }

        await save();
        expect(find.byType(AlertDialog), findsOneWidget);
        final fields = find.byType(TextFormField);
        await tester.enterText(fields.at(0), 'New item');
        await tester.enterText(fields.at(1), isService ? 'abc' : 'invalid');
        await tester.enterText(fields.at(2), isService ? '0' : 'Haircut');
        await save();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester.enterText(
          fields.at(1),
          isService ? '125000' : ' NEW@EXAMPLE.COM ',
        );
        await tester.enterText(fields.at(2), isService ? '45' : 'Haircut');
        if (!isService) {
          await tester.enterText(fields.at(2), 'newstaff123');
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.widgetWithText(FilterChip, 'Cắt tóc'),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilterChip, 'Cắt tóc'));
        }
        await save();
        expect(find.byType(AlertDialog), findsNothing);
        expect(find.text('New item'), findsOneWidget);
        final id = isService
            ? services.services.single.id
            : users.users.single.id;
        if (!isService) {
          expect(users.users.single.role, UserRole.staff);
          expect(users.users.single.email, 'new@example.com');
        }
        await tester.tap(find.byTooltip('Sửa New item'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextFormField>(fields.at(0)).controller!.text,
          'New item',
        );
        await tester.enterText(fields.at(0), 'Updated item');
        if (!isService) {
          expect(
            tester
                .widget<FilterChip>(find.widgetWithText(FilterChip, 'Cắt tóc'))
                .selected,
            isTrue,
          );
          FocusManager.instance.primaryFocus?.unfocus();
          await tester.pumpAndSettle();
          await tester.ensureVisible(
            find.widgetWithText(FilterChip, 'Gội đầu'),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilterChip, 'Gội đầu'));
        }
        await save();
        if (!isService) {
          expect(users.users.single.specializedCategoryIds, [
            'haircut',
            'hairWash',
          ]);
        }
        expect(find.text('Updated item'), findsOneWidget);
        expect(
          isService ? services.services.single.id : users.users.single.id,
          id,
        );
        await tester.tap(find.byTooltip('Xóa Updated item'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Hủy'));
        await tester.pumpAndSettle();
        expect(find.text('Updated item'), findsOneWidget);
        await tester.tap(find.byTooltip('Xóa Updated item'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
        await tester.pumpAndSettle();
        expect(find.text('Updated item'), findsNothing);
        if (isService) expect(services.services, isEmpty);
        expect(users.users, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('Staff filter and duplicate email handling', (tester) async {
    final provider = UserProvider(MockUserRepository(), access: testAccess());
    addTearDown(provider.dispose);
    await tester.pumpWidget(
      BookingTestScope(
        manager: true,
        child: MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: provider),
            ChangeNotifierProvider(
              create: (_) => ServiceProvider(
                MockServiceRepository(),
                access: testAccess(),
              ),
            ),
          ],
          child: const MaterialApp(home: ManagerStaffScreen()),
        ),
      ),
    );
    expect(find.text('Manager Demo'), findsNothing);
    expect(find.text('Customer Demo'), findsNothing);
    await tester.tap(find.byTooltip('Thêm nhân viên'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Duplicate');
    await tester.enterText(fields.at(1), ' ADMIN@EXAMPLE.COM ');
    await tester.enterText(fields.at(2), 'newstaff123');
    await tester.enterText(fields.at(3), 'Hà Nội');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.widgetWithText(FilterChip, 'Cắt tóc'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'Cắt tóc'));
    await tester.tap(find.widgetWithText(FilledButton, 'Lưu'));
    await tester.pumpAndSettle();
    expect(find.text('Email đã được sử dụng.'), findsOneWidget);
    expect(provider.users, hasLength(10));
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
