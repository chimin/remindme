// ignore_for_file: invalid_use_of_visible_for_testing_member

import '../scenario_runner.dart';
import 'dart:ui' show CheckedState;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:remindme/widgets/trailing_checked_menu_item.dart';

ScenarioCases defineScenarios() {
  final scenarios = <String, ScenarioFactory>{};
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

  scenarios['0'] = (state) async {
    final tester = state.tester!;

    state.next = () async {
      await pumpMenu(tester, checked: true);
      state.next = () async {
        expect(find.byIcon(Icons.done), findsOneWidget);
        expect(
          tester.getTopLeft(find.byIcon(Icons.done)).dx,
          greaterThan(tester.getTopRight(find.text('Tasks')).dx),
        );
      };
    };
  };

  scenarios['1'] = (state) async {
    final tester = state.tester!;

    state.next = () async {
      await pumpMenu(tester, checked: false);
      state.next = () async {
        expect(find.byIcon(Icons.done), findsNothing);
        expect(find.text('Tasks'), findsOneWidget);
      };
    };
  };

  scenarios['2'] = (state) async {
    final tester = state.tester!;

    state.next = () async {
      await pumpMenu(tester, checked: true);
      final semantics = tester.getSemantics(find.text('Tasks'));
      state.next = () async {
        expect(semantics.flagsCollection.isChecked, CheckedState.isTrue);
      };
    };
  };

  scenarios['3'] = (state) async {
    final tester = state.tester!;

    state.next = () async {
      await pumpMenu(
        tester,
        checked: true,
        label: 'A very long task list name that does not fit the menu',
      );
      state.next = () async {
        expect(tester.takeException(), isNull);
        expect(find.byIcon(Icons.done), findsOneWidget);
      };
    };
  };
  return scenarios;
}
