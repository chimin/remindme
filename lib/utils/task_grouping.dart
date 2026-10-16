import 'package:googleapis/tasks/v1.dart';

import '../models/task_item.dart';

/// Groups [tasks] by due date, exactly like the app's task home screen, and
/// returns the groups in display order (Overdue, Today, future).
///
/// All overdue tasks are combined under a single "Overdue" group regardless of
/// their exact due date. Tasks without a due date are placed in the "Today"
/// group, matching the app's existing behavior.
List<TaskGroup> groupTasksByDueDate(List<Task> tasks, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);

  final overdueTasks = <Task>[];
  final todayTasks = <Task>[];
  final futureTasks = <DateTime, List<Task>>{};

  for (final task in tasks) {
    DateTime? date;
    final due = task.due;
    if (due != null) {
      final parsed = DateTime.tryParse(due);
      if (parsed != null) {
        date = DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    // Tasks without a due date fall into the Today bucket.
    final key = date ?? today;
    if (key.isBefore(today)) {
      overdueTasks.add(task);
    } else if (key.isAtSameMomentAs(today)) {
      todayTasks.add(task);
    } else {
      futureTasks.putIfAbsent(key, () => <Task>[]).add(task);
    }
  }

  final groups = <TaskGroup>[];
  if (overdueTasks.isNotEmpty) {
    groups.add(
      TaskGroup(title: 'Overdue', category: 'overdue', tasks: overdueTasks),
    );
  }
  if (todayTasks.isNotEmpty) {
    groups.add(
      TaskGroup(title: 'Today', category: 'today', tasks: todayTasks),
    );
  }
  final futureKeys = futureTasks.keys.toList()..sort();
  for (final key in futureKeys) {
    groups.add(
      TaskGroup(
        title: '${key.year}-${key.month.toString().padLeft(2, '0')}'
            '-${key.day.toString().padLeft(2, '0')}',
        category: 'future',
        tasks: futureTasks[key]!,
      ),
    );
  }
  return groups;
}

/// Builds a flat, JSON-serializable list of display items for the widget: a
/// header entry per group followed by its task entries, in order.
///
/// Each entry is a JSON-serializable map.
List<Map<String, dynamic>> buildWidgetDisplayItems(
  List<Task> tasks,
  DateTime now,
) {
  final groups = groupTasksByDueDate(tasks, now);
  final items = <Map<String, dynamic>>[];
  for (final group in groups) {
    items.add({
      'type': 'header',
      'title': group.title,
      'category': group.category,
    });
    for (final task in group.tasks) {
      final item = TaskItem.fromTask(task);
      items.add({
        'type': 'task',
        'id': item.id,
        'title': item.title,
        'completed': item.completed,
      });
    }
  }
  return items;
}
