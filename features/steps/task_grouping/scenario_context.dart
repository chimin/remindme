import '../scenario_runner.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:remindme/utils/task_grouping.dart';

ScenarioCases defineScenarios() {
  final scenarios = <String, ScenarioFactory>{};

  scenarios['0'] = (state) async {
    state.next = () async {
      final items = buildWidgetDisplayItems([], DateTime(2026, 1, 15, 10));
      state.next = () async {
        expect(items, isEmpty);
      };
    };
  };

  scenarios['1'] = (state) async {
    state.next = () async {
      final now = DateTime(2026, 1, 15, 10);
      final tasks = [
        Task(id: 'a', title: 'No due date'),
        Task(id: 'b', title: 'Also no due date'),
      ];
      final items = buildWidgetDisplayItems(tasks, now);
      state.next = () async {
        expect(items, hasLength(3));
        expect(items[0]['type'], 'header');
        expect(items[0]['title'], 'No due date');
        expect(items[0]['category'], 'noDueDate');
        expect(items[1]['type'], 'task');
        expect(items[1]['title'], 'No due date');
        expect(items[1]['completed'], isFalse);
        expect(items[2]['type'], 'task');
        expect(items[2]['title'], 'Also no due date');
      };
    };
  };

  scenarios['2'] = (state) async {
    state.next = () async {
      final now = DateTime(2026, 1, 15, 10);
      final tasks = [
        Task(id: 'a', title: 'Broken due date', due: 'not-a-date'),
      ];
      final items = buildWidgetDisplayItems(tasks, now);
      state.next = () async {
        expect(items, hasLength(2));
        expect(items[0]['type'], 'header');
        expect(items[0]['title'], 'No due date');
        expect(items[0]['category'], 'noDueDate');
        expect(items[1]['type'], 'task');
        expect(items[1]['title'], 'Broken due date');
      };
    };
  };

  scenarios['3'] = (state) async {
    state.next = () async {
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
      state.next = () async {
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

        expect(items[8]['title'], 'Tomorrow');
        expect(items[8]['category'], 'future');
        expect(items[9]['title'], 'Future task 1');
        expect(items[10]['title'], 'Tue, Jan 20');
        expect(items[10]['category'], 'future');
        expect(items[11]['title'], 'Future task 2');
      };
    };
  };

  scenarios['4'] = (state) async {
    state.next = () async {
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
      state.next = () async {
        expect(overdueHeader['category'], 'overdue');
        expect(noDueDateHeader['category'], 'noDueDate');
        expect(todayHeader['category'], 'today');
      };
    };
  };

  scenarios['5'] = (state) async {
    state.next = () async {
      final now = DateTime(2026, 1, 15, 10);
      final tasks = [Task(id: 'a', title: 'Task')];

      final items = buildWidgetDisplayItems(tasks, now, taskListName: 'Work');
      state.next = () async {
        expect(items.first['type'], 'tasklist');
        expect(items.first['title'], 'Work');
        expect(items[1]['type'], 'header');
      };
    };
  };

  scenarios['6'] = (state) async {
    state.next = () async {
      final items = buildWidgetDisplayItems(
        [],
        DateTime(2026, 1, 15, 10),
        taskListName: 'Work',
      );
      state.next = () async {
        expect(items, hasLength(1));
        expect(items[0]['type'], 'tasklist');
        expect(items[0]['title'], 'Work');
      };
    };
  };

  scenarios['7'] = (state) async {
    state.next = () async {
      final now = DateTime(2026, 1, 15, 10);
      final tasks = [Task(id: 'a', title: 'Task')];

      final items = buildWidgetDisplayItems(tasks, now, taskListName: '   ');
      state.next = () async {
        expect(items.map((e) => e['type']).toList(), ['header', 'task']);
      };
    };
  };

  scenarios['8'] = (state) async {
    state.next = () async {
      final now = DateTime(2026, 1, 15, 10);
      final tasks = [Task(id: 'a', title: 'Task')];

      final items = buildWidgetDisplayItems(tasks, now);
      state.next = () async {
        expect(items.map((e) => e['type']).toList(), ['header', 'task']);
      };
    };
  };

  scenarios['9'] = (state) async {
    state.next = () async {
      final now = DateTime(2026, 1, 15, 10);
      final tasks = [
        Task(id: 'a', title: 'Open task', due: '2026-01-15'),
        Task(
          id: 'b',
          title: 'Done task',
          status: 'completed',
          due: '2026-01-15',
        ),
      ];

      final items = buildWidgetDisplayItems(tasks, now);
      state.next = () async {
        expect(items.map((e) => e['type']).toList(), ['header', 'task']);
        expect(items[1]['title'], 'Open task');
      };
    };
  };

  scenarios['10'] = (state) async {
    state.next = () async {
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
      state.next = () async {
        expect(items.map((e) => e['title']).toList(), ['Today', 'Open today']);
      };
    };
  };

  scenarios['11'] = (state) async {
    state.next = () async {
      final now = DateTime(2026, 1, 15, 10);
      final tasks = [
        Task(id: 'a', title: 'Open task', due: '2026-01-15'),
        Task(
          id: 'b',
          title: 'Done task',
          status: 'completed',
          due: '2026-01-15',
        ),
      ];

      final groups = groupTasksByDueDate(tasks, now);
      state.next = () async {
        expect(groups, hasLength(1));
        expect(groups.first.tasks, hasLength(2));
      };
    };
  };

  scenarios['12'] = (state) async {
    state.next = () async {
      final now = DateTime(2026, 1, 15, 10);
      final tasks = [
        Task(id: 'a', title: 'Open task', due: '2026-01-15'),
        Task(
          id: 'b',
          title: 'Done task',
          status: 'completed',
          due: '2026-01-15',
        ),
      ];

      final groups = groupTasksByDueDate(tasks, now, showCompleted: false);
      state.next = () async {
        expect(groups, hasLength(1));
        expect(groups.first.tasks, hasLength(1));
        expect(groups.first.tasks.first.title, 'Open task');
      };
    };
  };

  scenarios['13'] = (state) async {
    state.next = () async {
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
      state.next = () async {
        expect(groups, hasLength(1));
        expect(groups.first.title, 'Today');
      };
    };
  };

  scenarios['14'] = (state) async {
    state.next = () async {
      final now = DateTime(2026, 12, 31, 23, 59);
      state.next = () async {
        expect(formatTaskDate(DateTime.utc(2026, 12, 30), now), 'Yesterday');
        expect(formatTaskDate(DateTime.utc(2026, 12, 31), now), 'Today');
        expect(formatTaskDate(DateTime.utc(2027, 1, 1), now), 'Tomorrow');
        expect(
          formatTaskDate(DateTime.utc(2027, 1, 2), now),
          'Sat, Jan 2, 2027',
        );
      };
    };
  };

  scenarios['15'] = (state) async {
    state.next = () async {
      state.next = () async {
        expect(
          formatTaskDate(
            DateTime.utc(2026, 10, 27),
            DateTime(2026, 10, 26, 23),
          ),
          'Tomorrow',
        );
        expect(
          formatTaskDate(DateTime(2026, 11, 2), DateTime(2026, 10, 26)),
          'Mon, Nov 2',
        );
      };
    };
  };

  scenarios['16'] = (state) async {
    state.next = () async {
      final now = DateTime(2026, 12, 31, 23, 59);
      final tasks = [
        Task(id: 'later', title: 'Later', due: '2027-01-02T00:00:00.000Z'),
        Task(
          id: 'tomorrow',
          title: 'Next day',
          due: '2027-01-01T00:00:00.000Z',
        ),
        Task(id: 'today', title: 'Now', due: '2026-12-31T00:00:00.000Z'),
        Task(id: 'no-date', title: 'Unscheduled'),
        Task(id: 'overdue', title: 'Late', due: '2026-12-30T00:00:00.000Z'),
      ];
      final headers = buildWidgetDisplayItems(
        tasks,
        now,
      ).where((item) => item['type'] == 'header').toList();
      state.next = () async {
        expect(headers.map((item) => item['title']), [
          'Overdue',
          'No due date',
          'Today',
          'Tomorrow',
          'Sat, Jan 2, 2027',
        ]);
        state.next = () async {
          final groups = groupTasksByDueDate(tasks, now, showCompleted: false);
          state.next = () async {
            expect(
              headers.map((item) => item['title']),
              groups.map((group) => formatTaskGroupTitle(group.title, now)),
            );
            expect(headers.map((item) => item['category']), [
              'overdue',
              'noDueDate',
              'today',
              'future',
              'future',
            ]);
            expect(
              buildWidgetDisplayItems(tasks, now)
                  .where((item) => item['type'] == 'task')
                  .map((item) => item['id']),
              ['overdue', 'no-date', 'today', 'tomorrow', 'later'],
            );
          };
        };
      };
    };
  };

  scenarios['17'] = (state) async {
    state.next = () async {
      final items = buildWidgetDisplayItems([
        Task(id: 'next', title: 'Next month', due: '2026-02-01T00:00:00.000Z'),
      ], DateTime(2026, 1, 31, 23));
      state.next = () async {
        expect(items.first['title'], 'Tomorrow');
      };
    };
  };

  scenarios['18'] = (state) async {
    state.next = () async {
      for (final title in ['Overdue', 'No due date', 'Today', 'Completed']) {
        expect(formatTaskGroupTitle(title, DateTime(2026, 1, 15)), title);
      }

      state.next = () async {};
    };
  };
  scenarios['19'] = (state) async {
    state.next = () async {
      final items = buildWidgetDisplayItems(
        [Task(id: 'task/id', title: 'Task')],
        DateTime(2026, 1, 15),
        taskListId: 'list/id',
      );
      final task = items.singleWhere((item) => item['type'] == 'task');
      state.next = () async {
        expect(task['id'], 'task/id');
        expect(task['taskListId'], 'list/id');
        state.next = () async {
          final legacy = buildWidgetDisplayItems([
            Task(id: 'task', title: 'Task'),
          ], DateTime(2026, 1, 15));
          state.next = () async {
            expect(legacy.last.containsKey('taskListId'), isFalse);
          };
        };
      };
    };
  };

  return scenarios;
}
