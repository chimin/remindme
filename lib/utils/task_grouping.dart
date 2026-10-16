import 'package:googleapis/tasks/v1.dart';

import '../models/task_item.dart';

/// Groups [tasks] by due date, exactly like the app's task home screen, and
/// returns the groups in display order (Today, Overdue, future).
///
/// Tasks without a due date are placed in the "Today" group, matching the
/// app's existing behavior.
List<TaskGroup> groupTasksByDueDate(List<Task> tasks, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);

  final buckets = <DateTime, List<Task>>{};
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
    buckets.putIfAbsent(key, () => <Task>[]).add(task);
  }

  final sortedKeys = buckets.keys.toList()..sort((a, b) {
        final isAToday = a.isAtSameMomentAs(today);
        final isBToday = b.isAtSameMomentAs(today);
        if (isAToday && !isBToday) return -1;
        if (!isAToday && isBToday) return 1;
        // Past dates before future dates.
        if (a.isBefore(today) && b.isAfter(today)) return -1;
        if (a.isAfter(today) && b.isBefore(today)) return 1;
        return a.compareTo(b);
      });

  return sortedKeys.map((date) {
    final isToday = date.isAtSameMomentAs(today);
    final isPast = date.isBefore(today);
    final String title;
    final String category;
    if (isToday) {
      title = 'Today';
      category = 'today';
    } else if (isPast) {
      title = 'Overdue';
      category = 'overdue';
    } else {
      title = '${date.year}-${date.month.toString().padLeft(2, '0')}'
          '-${date.day.toString().padLeft(2, '0')}';
      category = 'future';
    }
    return TaskGroup(
      title: title,
      category: category,
      tasks: buckets[date]!,
    );
  }).toList();
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
