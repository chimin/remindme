import 'dart:async';
import 'dart:convert';

import 'package:googleapis/tasks/v1.dart';
import 'package:home_widget/home_widget.dart';

import '../utils/log.dart';
import '../utils/task_grouping.dart';

/// Key under which the serialized, grouped task list is stored in the widget
/// shared preferences (written by the Flutter side, read by the Android
/// [TaskWidgetProvider]).
class WidgetService {
  WidgetService._();

  static const String dataKey = 'task_widget_data';

  /// Serializes [tasks] into the grouped display format and pushes it to the
  /// home-screen widget, triggering a native refresh.
  ///
  /// [taskListName] is the name of the task list the tasks belong to; when
  /// given it is shown as the widget title.
  ///
  /// Best-effort: platform errors (e.g. widget not registered during dev) are
  /// logged and never rethrown, so the app keeps working.
  static Future<void> updateWidget(
    List<Task> tasks, {
    String? taskListName,
  }) async {
    try {
      final data = buildWidgetDisplayItems(
        tasks,
        DateTime.now(),
        taskListName: taskListName,
      );
      final json = jsonEncode(data);
      await HomeWidget.saveWidgetData<String>(dataKey, json);
      await HomeWidget.updateWidget(androidName: 'TaskWidgetProvider');
    } catch (e, st) {
      logError('Failed to update widget', e, st);
    }
  }

  /// Clears the widget data and triggers a refresh so it shows an empty state.
  static Future<void> clearWidget() async {
    try {
      await HomeWidget.saveWidgetData<String>(dataKey, null);
      await HomeWidget.updateWidget(androidName: 'TaskWidgetProvider');
    } catch (e, st) {
      logError('Failed to clear widget', e, st);
    }
  }
}
