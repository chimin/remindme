import 'package:googleapis/tasks/v1.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:remindme/utils/task_grouping.dart';

void main() {
  test('empty tasks produce no display items', () {
    final items = buildWidgetDisplayItems([], DateTime(2026, 1, 15, 10));
    expect(items, isEmpty);
  });

  test('tasks without due dates land in Today (sorted first)', () {
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

  test('groups by Today, Overdue then future in order', () {
    final now = DateTime(2026, 1, 15, 10);
    final tasks = [
      // future
      Task(id: 'future', title: 'Future task', due: '2026-01-20'),
      // today
      Task(id: 'today', title: 'Today task', due: '2026-01-15'),
      // overdue
      Task(id: 'overdue', title: 'Old task', due: '2026-01-10'),
      // completed today
      Task(id: 'done', title: 'Done today', status: 'completed', due: '2026-01-15'),
    ];

    final items = buildWidgetDisplayItems(tasks, now);

    // Today header + 2 tasks, Overdue header + 1 task, future date header + 1 task
    expect(items.map((e) => e['type']).toList(), [
      'header', 'task', 'task',
      'header', 'task',
      'header', 'task',
    ]);

    expect(items[0]['title'], 'Today');
    expect(items[1]['title'], 'Today task');
    expect(items[2]['title'], 'Done today');
    expect(items[2]['completed'], isTrue);

    expect(items[3]['title'], 'Overdue');
    expect(items[3]['category'], 'overdue');
    expect(items[4]['title'], 'Old task');

    expect(items[5]['title'], '2026-01-20');
    expect(items[5]['category'], 'future');
    expect(items[6]['title'], 'Future task');
  });

  test('overdue header uses red category and today is not red', () {
    final now = DateTime(2026, 1, 15, 10);
    final tasks = [
      Task(id: 'past', title: 'Past', due: '2026-01-01'),
      Task(id: 'today', title: 'Now', due: '2026-01-15'),
    ];
    final items = buildWidgetDisplayItems(tasks, now);

    // Today sorts first, then Overdue.
    final todayHeader = items[0];
    final pastHeader = items[2];
    expect(todayHeader['category'], 'today');
    expect(pastHeader['category'], 'overdue');
  });
}
