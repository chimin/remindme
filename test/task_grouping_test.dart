import 'package:googleapis/tasks/v1.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:remindme/utils/task_grouping.dart';

void main() {
  test('empty tasks produce no display items', () {
    final items = buildWidgetDisplayItems([], DateTime(2026, 1, 15, 10));
    expect(items, isEmpty);
  });

  test('tasks without due dates land in Today', () {
    final now = DateTime(2026, 1, 15, 10);
    final tasks = [
      Task(id: 'a', title: 'No due date'),
      Task(id: 'b', title: 'Also no due date'),
    ];
    final items = buildWidgetDisplayItems(tasks, now);

    expect(items, hasLength(3));
    expect(items[0]['type'], 'header');
    expect(items[0]['title'], 'Today');
    expect(items[0]['category'], 'today');
    expect(items[1]['type'], 'task');
    expect(items[1]['title'], 'No due date');
    expect(items[1]['completed'], isFalse);
    expect(items[2]['type'], 'task');
    expect(items[2]['title'], 'Also no due date');
  });

  test('groups by Overdue, Today then future in order', () {
    final now = DateTime(2026, 1, 15, 10);
    final tasks = [
      // overdue, different dates
      Task(id: 'overdue1', title: 'Overdue task 1', due: '2026-01-10'),
      Task(id: 'overdue2', title: 'Overdue task 2', due: '2026-01-05'),
      // today
      Task(id: 'today1', title: 'Today task 1', due: '2026-01-15'),
      Task(id: 'today2', title: 'Today task 2', due: '2026-01-15'),
      // future, different dates
      Task(id: 'future1', title: 'Future task 1', due: '2026-01-16'),
      Task(id: 'future2', title: 'Future task 2', due: '2026-01-20'),
    ];

    final items = buildWidgetDisplayItems(tasks, now);

    // Overdue header + 2 tasks (combined despite different dates), Today header + 2 tasks,
    // two future headers + 1 task each (future groups by exact date)
    expect(items.map((e) => e['type']).toList(), [
      'header', 'task', 'task',
      'header', 'task', 'task',
      'header', 'task',
      'header', 'task',
    ]);

    expect(items[0]['title'], 'Overdue');
    expect(items[0]['category'], 'overdue');
    expect(items[1]['title'], 'Overdue task 1');
    expect(items[2]['title'], 'Overdue task 2');

    expect(items[3]['title'], 'Today');
    expect(items[4]['title'], 'Today task 1');
    expect(items[5]['title'], 'Today task 2');

    expect(items[6]['category'], 'future');
    expect(items[7]['title'], 'Future task 1');
    expect(items[8]['category'], 'future');
    expect(items[9]['title'], 'Future task 2');
  });

  test('overdue header uses red category and today is not red', () {
    final now = DateTime(2026, 1, 15, 10);
    final tasks = [
      Task(id: 'past', title: 'Past', due: '2026-01-01'),
      Task(id: 'today', title: 'Now', due: '2026-01-15'),
    ];
    final items = buildWidgetDisplayItems(tasks, now);

    // Overdue sorts first, then Today.
    final overdueHeader = items[0];
    final todayHeader = items[2];
    expect(overdueHeader['category'], 'overdue');
    expect(todayHeader['category'], 'today');
  });
}
