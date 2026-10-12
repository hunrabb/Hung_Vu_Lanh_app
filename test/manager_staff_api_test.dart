import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ktgk/core/network/api_client.dart';
import 'package:ktgk/features/manager/presentation/manager_crud_dialogs.dart';

void main() {
  testWidgets(
    'API recruitment sends profile only, blocks double save and keeps conflict visible',
    (tester) async {
      final pending = Completer<void>();
      final bodies = <Map<String, dynamic>>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ManagerCrudDialog.apiStaff(
              save: (body) {
                bodies.add(body);
                return pending.future;
              },
            ),
          ),
        ),
      );
      final fields = find.byType(TextFormField);
      for (final entry in [
        ' API Staff ',
        ' Staff@Example.com ',
        '0901234567',
        'Hà Nội',
      ].asMap().entries) {
        await tester.enterText(fields.at(entry.key), entry.value);
      }
      await tester.ensureVisible(find.byType(FilterChip).first);
      await tester.tap(find.byType(FilterChip).first);
      await tester.ensureVisible(find.text('Lưu'));
      await tester.tap(find.text('Lưu'));
      await tester.pump();
      expect(bodies, hasLength(1));
      expect(bodies.single['name'], 'API Staff');
      expect(bodies.single['email'], 'staff@example.com');
      expect(
        bodies.single.keys,
        unorderedEquals([
          'name',
          'email',
          'phone',
          'address',
          'specializedCategoryIds',
        ]),
      );
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      pending.completeError(const ApiException(409, 'Email đã được sử dụng'));
      await tester.pumpAndSettle();
      expect(find.text('Email đã được sử dụng'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('API save finishing after disposal does not use stale context', (
    tester,
  ) async {
    final pending = Completer<void>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ManagerCrudDialog.apiStaff(save: (_) => pending.future),
        ),
      ),
    );
    final fields = find.byType(TextFormField);
    for (final entry in [
      'Staff',
      'staff@example.com',
      '0901234567',
      'Hà Nội',
    ].asMap().entries) {
      await tester.enterText(fields.at(entry.key), entry.value);
    }
    await tester.ensureVisible(find.byType(FilterChip).first);
    await tester.tap(find.byType(FilterChip).first);
    await tester.ensureVisible(find.text('Lưu'));
    await tester.tap(find.text('Lưu'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    pending.complete();
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
