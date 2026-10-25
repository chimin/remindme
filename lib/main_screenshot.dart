import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:provider/provider.dart';

import 'main.dart' show MyApp;
import 'services/tasks_repository.dart';
import 'services/widget_service.dart';

/// Separate entry point used only by the Android screenshot build.
Future<void> main() async {
  if (!kDebugMode) {
    throw StateError('Screenshot fixtures require a debug build');
  }
  WidgetsFlutterBinding.ensureInitialized();
  final repository = _ScreenshotRepository();
  // Publish the same fixture to the real Android widget before opening the UI.
  await WidgetService.updateWidget(repository.tasks, taskListName: 'My Tasks');
  runApp(
    ChangeNotifierProvider<TasksRepository>.value(
      value: repository,
      child: const MyApp(showDebugBanner: false),
    ),
  );
}

class _ScreenshotRepository extends TasksRepository {
  _ScreenshotRepository() {
    initialized = true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const titles = [
      'Renew library books',
      'Pick up groceries',
      'Plan weekend trip',
      'Book dentist appointment',
    ];
    const offsets = [-1, 0, 2, 5];
    tasks = List.generate(
      4,
      (index) => Task(
        id: 'screenshot-$index',
        title: titles[index],
        status: 'needsAction',
        due: DateTime(
          today.year,
          today.month,
          today.day + offsets[index],
        ).toIso8601String(),
      ),
    );
  }

  late final List<Task> tasks;

  @override
  bool get signedIn => true;

  @override
  String? get selectedTasklistId => 'screenshot-list';

  @override
  Future<List<TaskList>> getTaskLists() async => [
    TaskList(id: selectedTasklistId, title: 'My Tasks'),
  ];

  @override
  Future<List<Task>> getTasks(String tasklistId) async => tasks;
}
