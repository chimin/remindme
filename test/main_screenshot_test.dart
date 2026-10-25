import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:remindme/main_screenshot.dart' as screenshot;
import 'package:remindme/screens/task_home_screen.dart';
import 'package:remindme/services/tasks_repository.dart';

void main() {
  testWidgets(
    'main should display four dated tasks and publish matching widget data '
    'when the screenshot entry point starts',
    (tester) async {
      final payloads = <List<dynamic>>[];
      const channel = MethodChannel('home_widget');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'saveWidgetData') {
          payloads.add(
            jsonDecode((call.arguments as Map)['data'] as String)
                as List<dynamic>,
          );
        }
        return true;
      });
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      await screenshot.main();
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(TaskHomeScreen));
      final repository = context.read<TasksRepository>();
      final tasks = await repository.getTasks(repository.selectedTasklistId!);
      expect(tasks, hasLength(4));
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final dates = tasks.map((task) => DateTime.parse(task.due!)).toList();
      expect(dates.where((date) => date.isBefore(today)), hasLength(1));
      expect(dates.where((date) => date == today), hasLength(1));
      expect(dates.where((date) => date.isAfter(today)).toSet(), hasLength(2));
      for (final task in tasks) {
        expect(find.text(task.title!), findsOneWidget);
      }
      final widgetTasks = payloads.last
          .where((item) => item['type'] == 'task')
          .toList();
      expect(
        widgetTasks.map((item) => item['title']),
        tasks.map((task) => task.title),
      );
      expect(
        tester
            .widget<MaterialApp>(find.byType(MaterialApp))
            .debugShowCheckedModeBanner,
        isFalse,
      );
    },
  );
}
