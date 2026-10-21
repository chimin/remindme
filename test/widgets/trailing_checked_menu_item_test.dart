import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:remindme/widgets/trailing_checked_menu_item.dart';

void main() {
  Future<void> pumpMenu(
    WidgetTester tester, {
    required bool checked,
    String label = 'Tasks',
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PopupMenuButton<String>(
            onSelected: (_) {},
            itemBuilder: (context) => [
              TrailingCheckedMenuItem<String>(
                value: 'list-1',
                label: label,
                checked: checked,
              ),
            ],
            child: const Text('open'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'menu item should show the checkmark on the right when the item is checked',
    (WidgetTester tester) async {
      await pumpMenu(tester, checked: true);

      expect(find.byIcon(Icons.done), findsOneWidget);
      expect(
        tester.getTopLeft(find.byIcon(Icons.done)).dx,
        greaterThan(tester.getTopRight(find.text('Tasks')).dx),
      );
    },
  );

  testWidgets(
    'menu item should hide the checkmark when the item is not checked',
    (WidgetTester tester) async {
      await pumpMenu(tester, checked: false);

      expect(find.byIcon(Icons.done), findsNothing);
      expect(find.text('Tasks'), findsOneWidget);
    },
  );

  testWidgets(
    'menu item should report the checked state to accessibility tools',
    (WidgetTester tester) async {
      await pumpMenu(tester, checked: true);

      final semantics = tester.getSemantics(find.text('Tasks'));
      expect(semantics.flagsCollection.isChecked, CheckedState.isTrue);
    },
  );

  testWidgets(
    'menu item should fit the menu width when the label is long',
    (WidgetTester tester) async {
      await pumpMenu(
        tester,
        checked: true,
        label: 'A very long task list name that does not fit the menu',
      );

      expect(tester.takeException(), isNull);
      expect(find.byIcon(Icons.done), findsOneWidget);
    },
  );
}
