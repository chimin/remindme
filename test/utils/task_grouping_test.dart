import 'package:googleapis/tasks/v1.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:remindme/utils/task_grouping.dart';

void main() {
  test('empty tasks produce no display items', () {
    final items = buildWidgetDisplayItems([], DateTime(2026, 1, 15, 10));
    expect(items, isEmpty);
  });

  test('tasks without due dates land in the No due date group', () {
    final now = DateTime(2026, 1, 15, 10);
    final tasks = [
      Task(id: 'a', title: 'No due date'),
      Task(id: 'b', title: 'Also no due date'),
    ];
    final items = buildWidgetDisplayItems(tasks, now);

    expect(items, hasLength(3));
    expect(items[0]['type'], 'header');
    expect(items[0]['title'], 'No due date');
    expect(items[0]['category'], 'noDueDate');
    expect(items[1]['type'], 'task');
    expect(items[1]['title'], 'No due date');
    expect(items[1]['completed'], isFalse);
    expect(items[2]['type'], 'task');
    expect(items[2]['title'], 'Also no due date');
  });

  test('tasks with unparseable due dates land in the No due date group', () {
    final now = DateTime(2026, 1, 15, 10);
    final tasks = [Task(id: 'a', title: 'Broken due date', due: 'not-a-date')];
    final items = buildWidgetDisplayItems(tasks, now);

    expect(items, hasLength(2));
    expect(items[0]['type'], 'header');
    expect(items[0]['title'], 'No due date');
    expect(items[0]['category'], 'noDueDate');
    expect(items[1]['type'], 'task');
    expect(items[1]['title'], 'Broken due date');
  });

  test('groups by Overdue, No due date, Today then future in order', () {
    final now = DateTime(2026, 1, 15, 10);
    final tasks = [
      // overdue, different dates
      Task(id: 'overdue1', title: 'Overdue task 1', due: '2026-01-10'),
      Task(id: 'overdue2', title: 'Overdue task 2', due: '2026-01-05'),
      // no due date
      Task(id: 'nodate1', title: 'No due date task 1'),
      // today
      Task(id: 'today1', title: 'Today task 1', due: '2026-01-15'),
      Task(id: 'today2', title: 'Today task 2', due: '2026-01-15'),
      // future, different dates
      Task(id: 'future1', title: 'Future task 1', due: '2026-01-16'),
      Task(id: 'future2', title: 'Future task 2', due: '2026-01-20'),
    ];

    final items = buildWidgetDisplayItems(tasks, now);

    // Overdue header + 2 tasks (combined despite different dates), No due date
    // header + 1 task, Today header + 2 tasks, two future headers + 1 task
    // each (future groups by exact date)
    expect(items.map((e) => e['type']).toList(), [
      'header',
      'task',
      'task',
      'header',
      'task',
      'header',
      'task',
      'task',
      'header',
      'task',
      'header',
      'task',
    ]);

    expect(items[0]['title'], 'Overdue');
    expect(items[0]['category'], 'overdue');
    expect(items[1]['title'], 'Overdue task 1');
    expect(items[2]['title'], 'Overdue task 2');

    expect(items[3]['title'], 'No due date');
    expect(items[3]['category'], 'noDueDate');
    expect(items[4]['title'], 'No due date task 1');

    expect(items[5]['title'], 'Today');
    expect(items[6]['title'], 'Today task 1');
    expect(items[7]['title'], 'Today task 2');

    expect(items[8]['category'], 'future');
    expect(items[9]['title'], 'Future task 1');
    expect(items[10]['category'], 'future');
    expect(items[11]['title'], 'Future task 2');
  });

  test('overdue header uses red category and other headers are not red', () {
    final now = DateTime(2026, 1, 15, 10);
    final tasks = [
      Task(id: 'past', title: 'Past', due: '2026-01-01'),
      Task(id: 'nodate', title: 'No date'),
      Task(id: 'today', title: 'Now', due: '2026-01-15'),
    ];
    final items = buildWidgetDisplayItems(tasks, now);

    // Overdue sorts first, then No due date, then Today.
    final overdueHeader = items[0];
    final noDueDateHeader = items[2];
    final todayHeader = items[4];
    expect(overdueHeader['category'], 'overdue');
    expect(noDueDateHeader['category'], 'noDueDate');
    expect(todayHeader['category'], 'today');
  });

  test('buildWidgetDisplayItems should add task list name first '
      'when task list name is given', () {
    final now = DateTime(2026, 1, 15, 10);
    final tasks = [Task(id: 'a', title: 'Task')];

    final items = buildWidgetDisplayItems(tasks, now, taskListName: 'Work');

    expect(items.first['type'], 'tasklist');
    expect(items.first['title'], 'Work');
    expect(items[1]['type'], 'header');
  });

  test('buildWidgetDisplayItems should add task list name when '
      'there are no tasks', () {
    final items = buildWidgetDisplayItems(
      [],
      DateTime(2026, 1, 15, 10),
      taskListName: 'Work',
    );

    expect(items, hasLength(1));
    expect(items[0]['type'], 'tasklist');
    expect(items[0]['title'], 'Work');
  });

  test('buildWidgetDisplayItems should skip task list name when '
      'task list name is blank', () {
    final now = DateTime(2026, 1, 15, 10);
    final tasks = [Task(id: 'a', title: 'Task')];

    final items = buildWidgetDisplayItems(tasks, now, taskListName: '   ');

    expect(items.map((e) => e['type']).toList(), ['header', 'task']);
  });

  test('buildWidgetDisplayItems should skip task list name when '
      'task list name is not given', () {
    final now = DateTime(2026, 1, 15, 10);
    final tasks = [Task(id: 'a', title: 'Task')];

    final items = buildWidgetDisplayItems(tasks, now);

    expect(items.map((e) => e['type']).toList(), ['header', 'task']);
  });

  test('buildWidgetDisplayItems should exclude completed tasks', () {
    final now = DateTime(2026, 1, 15, 10);
    final tasks = [
      Task(id: 'a', title: 'Open task', due: '2026-01-15'),
      Task(id: 'b', title: 'Done task', status: 'completed', due: '2026-01-15'),
    ];

    final items = buildWidgetDisplayItems(tasks, now);

    expect(items.map((e) => e['type']).toList(), ['header', 'task']);
    expect(items[1]['title'], 'Open task');
  });

  test(
    'buildWidgetDisplayItems should drop groups with only completed tasks',
    () {
      final now = DateTime(2026, 1, 15, 10);
      final tasks = [
        Task(id: 'a', title: 'Open today', due: '2026-01-15'),
        Task(
          id: 'b',
          title: 'Done tomorrow',
          status: 'completed',
          due: '2026-01-16',
        ),
      ];

      final items = buildWidgetDisplayItems(tasks, now);

      expect(items.map((e) => e['title']).toList(), ['Today', 'Open today']);
    },
  );

  test('groupTasksByDueDate should include completed tasks by default', () {
    final now = DateTime(2026, 1, 15, 10);
    final tasks = [
      Task(id: 'a', title: 'Open task', due: '2026-01-15'),
      Task(id: 'b', title: 'Done task', status: 'completed', due: '2026-01-15'),
    ];

    final groups = groupTasksByDueDate(tasks, now);

    expect(groups, hasLength(1));
    expect(groups.first.tasks, hasLength(2));
  });

  test('groupTasksByDueDate should exclude completed tasks when '
      'showCompleted is false', () {
    final now = DateTime(2026, 1, 15, 10);
    final tasks = [
      Task(id: 'a', title: 'Open task', due: '2026-01-15'),
      Task(id: 'b', title: 'Done task', status: 'completed', due: '2026-01-15'),
    ];

    final groups = groupTasksByDueDate(tasks, now, showCompleted: false);

    expect(groups, hasLength(1));
    expect(groups.first.tasks, hasLength(1));
    expect(groups.first.tasks.first.title, 'Open task');
  });

  test('groupTasksByDueDate should drop groups with only completed tasks '
      'when showCompleted is false', () {
    final now = DateTime(2026, 1, 15, 10);
    final tasks = [
      Task(id: 'a', title: 'Open today', due: '2026-01-15'),
      Task(
        id: 'b',
        title: 'Done tomorrow',
        status: 'completed',
        due: '2026-01-16',
      ),
    ];

    final groups = groupTasksByDueDate(tasks, now, showCompleted: false);

    expect(groups, hasLength(1));
    expect(groups.first.title, 'Today');
  });

  test(
    'formatTaskDate should use relative labels when dates cross a year boundary',
    () {
      final now = DateTime(2026, 12, 31, 23, 59);
      expect(formatTaskDate(DateTime.utc(2026, 12, 30), now), 'Yesterday');
      expect(formatTaskDate(DateTime.utc(2026, 12, 31), now), 'Today');
      expect(formatTaskDate(DateTime.utc(2027, 1, 1), now), 'Tomorrow');
      expect(formatTaskDate(DateTime.utc(2027, 1, 2), now), 'Sat, Jan 2, 2027');
    },
  );

  test(
    'formatTaskDate should preserve calendar days when a due date uses UTC',
    () {
      expect(
        formatTaskDate(DateTime.utc(2026, 10, 27), DateTime(2026, 10, 26, 23)),
        'Tomorrow',
      );
      expect(
        formatTaskDate(DateTime(2026, 11, 2), DateTime(2026, 10, 26)),
        'Mon, Nov 2',
      );
    },
  );
}
