import 'package:googleapis/tasks/v1.dart';

import '../models/task_item.dart';

/// Groups [tasks] by due date, exactly like the app's task home screen, and
/// returns the groups in display order (Overdue, No due date, Today, future).
///
/// All overdue tasks are combined under a single "Overdue" group regardless of
/// their exact due date. Tasks without a due date are placed in a dedicated
/// "No due date" group.
///
/// When [showCompleted] is false, completed tasks are left out entirely and
/// groups that only contained completed tasks are dropped.
List<TaskGroup> groupTasksByDueDate(
  List<Task> tasks,
  DateTime now, {
  bool showCompleted = true,
}) {
  final today = DateTime(now.year, now.month, now.day);

  final overdueTasks = <Task>[];
  final noDueDateTasks = <Task>[];
  final todayTasks = <Task>[];
  final futureTasks = <DateTime, List<Task>>{};

  for (final task in tasks) {
    if (!showCompleted && task.status == 'completed') continue;
    DateTime? date;
    final due = task.due;
    if (due != null) {
      final parsed = DateTime.tryParse(due);
      if (parsed != null) {
        date = DateTime(parsed.year, parsed.month, parsed.day);
      }
    }
    // Tasks without a due date (or with an unparseable one) get their own group.
    if (date == null) {
      noDueDateTasks.add(task);
    } else if (date.isBefore(today)) {
      overdueTasks.add(task);
    } else if (date.isAtSameMomentAs(today)) {
      todayTasks.add(task);
    } else {
      futureTasks.putIfAbsent(date, () => <Task>[]).add(task);
    }
  }

  final groups = <TaskGroup>[];
  if (overdueTasks.isNotEmpty) {
    groups.add(
      TaskGroup(title: 'Overdue', category: 'overdue', tasks: overdueTasks),
    );
  }
  if (noDueDateTasks.isNotEmpty) {
    groups.add(
      TaskGroup(
        title: 'No due date',
        category: 'noDueDate',
        tasks: noDueDateTasks,
      ),
    );
  }
  if (todayTasks.isNotEmpty) {
    groups.add(TaskGroup(title: 'Today', category: 'today', tasks: todayTasks));
  }
  final futureKeys = futureTasks.keys.toList()..sort();
  for (final key in futureKeys) {
    groups.add(
      TaskGroup(
        title:
            '${key.year}-${key.month.toString().padLeft(2, '0')}'
            '-${key.day.toString().padLeft(2, '0')}',
        category: 'future',
        tasks: futureTasks[key]!,
      ),
    );
  }
  return groups;
}

/// Builds a flat, JSON-serializable list of display items for the widget: the
/// task list title (when [taskListName] is given), then a header entry per
/// group followed by its task entries, in order.
///
/// Completed tasks are never included: the home-screen widget only shows
/// outstanding items.
///
/// Each entry is a JSON-serializable map.
List<Map<String, dynamic>> buildWidgetDisplayItems(
  List<Task> tasks,
  DateTime now, {
  String? taskListName,
}) {
  final groups = groupTasksByDueDate(tasks, now, showCompleted: false);
  final items = <Map<String, dynamic>>[];
  final name = taskListName?.trim();
  if (name != null && name.isNotEmpty) {
    items.add({'type': 'tasklist', 'title': name});
  }
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

/// Formats the calendar date stored by Google Tasks without shifting timezones.
String formatTaskDate(DateTime date, DateTime now) {
  final day = DateTime.utc(date.year, date.month, date.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  final difference = day.difference(today).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Tomorrow';
  if (difference == -1) return 'Yesterday';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  final label =
      '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  return date.year == now.year ? label : '$label, ${date.year}';
}
