import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remindme/widgets/delete_task_confirmation_dialog.dart';

void main() {
  Future<void> openDialog(
    WidgetTester tester,
    void Function(bool?) onResult,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                onResult(
                  await showDialog<bool>(
                    context: context,
                    builder: (_) => const DeleteTaskConfirmationDialog(
                      taskTitle: 'Water plants',
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets('confirmation dialog should display the task title when opened', (
    tester,
  ) async {
    await openDialog(tester, (_) {});
    expect(find.text('Delete task?'), findsOneWidget);
    expect(
      find.text('Water plants\n\nThis action cannot be undone.'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete'), findsOneWidget);
  });

  for (final action in ['Delete', 'Cancel', 'barrier', 'back']) {
    final expected = action == 'Delete'
        ? true
        : action == 'Cancel'
        ? false
        : null;
    final trigger = action == 'barrier'
        ? 'the barrier is tapped'
        : action == 'back'
        ? 'back navigation is requested'
        : '$action is tapped';
    testWidgets('confirmation dialog should return $expected when $trigger', (
      tester,
    ) async {
      bool? result;
      var returned = false;
      await openDialog(tester, (value) {
        result = value;
        returned = true;
      });
      if (action == 'barrier') {
        await tester.tapAt(const Offset(5, 5));
      } else if (action == 'back') {
        await tester.binding.handlePopRoute();
      } else {
        await tester.tap(find.text(action));
      }
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(result, expected);
      expect(find.byType(DeleteTaskConfirmationDialog), findsNothing);
    });
  }
}
