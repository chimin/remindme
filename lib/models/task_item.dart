import 'package:googleapis/tasks/v1.dart';

/// A simplified, serializable representation of a Google Task used by the
/// home-screen widget and the local Hive cache.
class TaskItem {
  TaskItem({
    this.id,
    required this.title,
    this.completed = false,
    this.dueDate,
    this.updatedAt,
    this.isDeleted = false,
    this.dirty = false,
  });

  final String? id;
  final String title;
  final bool completed;

  /// ISO 8601 due date string (UTC, date only) as received from the API, or
  /// null when the task has no due date.
  final String? dueDate;

  /// Last-write-wins timestamp (milliseconds since the epoch) used for
  /// conflict resolution during sync.
  final int? updatedAt;

  /// Soft-delete flag: the task was deleted locally and awaits remote removal.
  final bool isDeleted;

  /// True when a local change has not yet been pushed to the remote API.
  final bool dirty;

  factory TaskItem.fromTask(Task task) {
    return TaskItem(
      id: task.id,
      title: task.title ?? '(no title)',
      completed: task.status == 'completed',
      dueDate: task.due,
      updatedAt: task.updated == null
          ? null
          : DateTime.tryParse(task.updated!)?.millisecondsSinceEpoch,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'completed': completed,
        'dueDate': dueDate,
        'updatedAt': updatedAt,
        'isDeleted': isDeleted,
        'dirty': dirty,
      };

  factory TaskItem.fromJson(Map<String, dynamic> json) => TaskItem(
        id: json['id'] as String?,
        title: json['title'] as String? ?? '(no title)',
        completed: json['completed'] as bool? ?? false,
        dueDate: json['dueDate'] as String?,
        updatedAt: json['updatedAt'] as int?,
        isDeleted: json['isDeleted'] as bool? ?? false,
        dirty: json['dirty'] as bool? ?? false,
      );
}

/// A group of tasks sharing the same due date, ready to be displayed with a
/// section header (Today / Overdue / a specific date).
class TaskGroup {
  TaskGroup({
    required this.title,
    required this.category,
    required this.tasks,
  });

  /// Human readable header: "Today", "Overdue" or "YYYY-MM-DD".
  final String title;

  /// Machine readable category: "today", "overdue" or "future". Used by the
  /// widget to pick header colors.
  final String category;

  /// The original [Task] objects in this group, preserved so the screen can
  /// edit/delete them with full data (notes, status, etc.).
  final List<Task> tasks;
}
