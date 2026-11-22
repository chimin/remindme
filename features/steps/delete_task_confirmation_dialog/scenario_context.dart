// ignore_for_file: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member

import '../scenario_runner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remindme/widgets/delete_task_confirmation_dialog.dart';

ScenarioCases defineScenarios() {
  final scenarios = <String, ScenarioFactory>{};
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

  scenarios['0'] = (state) async {
    final tester = state.tester!;

    state.next = () async {
      await openDialog(tester, (_) {});
      state.next = () async {
        expect(find.text('Delete task?'), findsOneWidget);
        expect(
          find.text('Water plants\n\nThis action cannot be undone.'),
          findsOneWidget,
        );
        expect(find.text('Cancel'), findsOneWidget);
        expect(find.text('Delete'), findsOneWidget);
      };
    };
  };

  for (final action in ['Delete', 'Cancel', 'barrier', 'back']) {
    final expected = action == 'Delete'
        ? true
        : action == 'Cancel'
        ? false
        : null;
    scenarios['1:$action'] = (state) async {
      final tester = state.tester!;
      bool? result;
      var returned = false;
      state.next = () async {
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
        state.next = () async {
          expect(returned, isTrue);
          expect(result, expected);
          expect(find.byType(DeleteTaskConfirmationDialog), findsNothing);
        };
      };
    };
  }
  return scenarios;
}
