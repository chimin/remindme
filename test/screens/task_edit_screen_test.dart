import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:provider/provider.dart';

import 'package:remindme/screens/task_edit_screen.dart';
import 'package:remindme/services/tasks_repository.dart';
import 'package:remindme/models/task_metadata.dart';

import 'golden_test_helper.dart';

void main() {
  setUpAll(() async {
    final robotoBytes = await File(
      'test/fonts/roboto-regular.ttf',
    ).readAsBytes();
    final robotoLoader = FontLoader('Roboto')
      ..addFont(Future<ByteData>.value(ByteData.view(robotoBytes.buffer)));
    await robotoLoader.load();

    final materialIconsBytes = await File(
      'test/fonts/materialicons-regular.otf',
    ).readAsBytes();
    final materialIconsLoader = FontLoader('MaterialIcons')
      ..addFont(
        Future<ByteData>.value(ByteData.view(materialIconsBytes.buffer)),
      );
    await materialIconsLoader.load();
  });

  testWidgets('add task page should show empty form when task list selected', (
    WidgetTester tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      MethodChannel('home_widget'),
      (_) async => null,
    );

    final mock = MockTasksRepository()
      ..taskLists.add(TaskList(id: 'list-1', title: 'Tasks'))
      ..signInMock(tasklistId: 'list-1');

    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      ChangeNotifierProvider<TasksRepository>.value(
        value: mock,
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
              fontFamily: 'Roboto',
            ),
            home: TaskEditScreen(taskListId: 'list-1'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('New Task'), findsOneWidget);
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);

    await expectLater(
      find.byKey(boundaryKey),
      matchesGoldenFile('golden/task_edit_screen.png'),
    );
  });

  Future<void> pumpEditor(
    WidgetTester tester,
    RecordingTasksRepository repo, {
    Task? task,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TasksRepository>.value(
        value: repo,
        child: MaterialApp(
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
            useMaterial3: true,
            fontFamily: 'Roboto',
          ),
          home: RepaintBoundary(
            key: const ValueKey('editor'),
            child: TaskEditScreen(taskListId: 'list-1', task: task),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'save should preserve extensible metadata when a repeating task is edited',
    (tester) async {
      final repo = RecordingTasksRepository();
      final task = Task(
        id: 'task',
        title: 'Water plants',
        status: 'needsAction',
        due: '2030-02-28T00:00:00.000Z',
        notes: TaskMetadata('Keep the soil moist', {
          'recurrence': {
            'frequency': 'monthly',
            'interval': 2,
            'anchorDay': 31,
            'futureRule': true,
          },
          'futureFeature': {'color': 'green'},
        }).encode(),
      );
      await pumpEditor(tester, repo, task: task);
      final notes = tester.widget<TextField>(find.byType(TextField).last);
      expect(notes.controller!.text, 'Keep the soil moist');
      expect(find.text('Monthly'), findsOneWidget);
      await expectLater(
        find.byKey(const ValueKey('editor')),
        matchesGoldenFile('golden/task_edit_screen_repeat.png'),
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = TaskMetadata.parse(repo.saved!.notes);
      expect(saved.data['futureFeature'], {'color': 'green'});
      expect(saved.data['recurrence'], {
        'frequency': 'monthly',
        'interval': 2,
        'anchorDay': 31,
        'futureRule': true,
      });
    },
  );

  testWidgets('save should require a due date when repeat is selected', (
    tester,
  ) async {
    final repo = RecordingTasksRepository();
    await pumpEditor(tester, repo);
    await tester.enterText(find.byType(TextFormField), 'Water plants');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Daily').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a due date for repeating tasks'), findsOneWidget);
    expect(repo.saved, isNull);
  });

  testWidgets('save should remove only recurrence when repeat is disabled', (
    tester,
  ) async {
    final repo = RecordingTasksRepository();
    await pumpEditor(
      tester,
      repo,
      task: Task(
        id: 'task',
        title: 'Water plants',
        due: '2030-01-01T00:00:00Z',
        notes: TaskMetadata('Notes', {
          'recurrence': {'frequency': 'daily'},
          'futureFeature': 123,
        }).encode(),
      ),
    );
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Never').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final saved = TaskMetadata.parse(repo.saved!.notes);
    expect(saved.data.containsKey('recurrence'), isFalse);
    expect(saved.data['futureFeature'], 123);
    expect(saved.notes, 'Notes');
  });

  testWidgets('save should preserve an unknown rule when repeat is unchanged', (
    tester,
  ) async {
    final repo = RecordingTasksRepository();
    final rule = {'frequency': 'future-frequency', 'setting': true};
    await pumpEditor(
      tester,
      repo,
      task: Task(
        id: 'task',
        title: 'Water plants',
        notes: TaskMetadata('Notes', {'recurrence': rule}).encode(),
      ),
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(TaskMetadata.parse(repo.saved!.notes).data['recurrence'], rule);
  });

  testWidgets(
    'save should remain reachable when the keyboard reduces available height',
    (tester) async {
      final repo = RecordingTasksRepository();
      tester.view.viewInsets = const FakeViewPadding(bottom: 600);
      addTearDown(tester.view.resetViewInsets);
      await pumpEditor(tester, repo);
      await tester.enterText(find.byType(TextFormField), 'Water plants');
      await tester.ensureVisible(find.text('Save'));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(repo.saved!.title, 'Water plants');
    },
  );
}

class RecordingTasksRepository extends MockTasksRepository {
  Task? saved;

  @override
  Future<Task> createTask(
    String tasklistId, {
    required String title,
    String? notes,
    DateTime? due,
  }) async {
    return saved = Task(
      id: 'created',
      title: title,
      notes: notes,
      due: due?.toIso8601String(),
    );
  }

  @override
  Future<Task> updateTask(
    String tasklistId,
    String taskId, {
    String? title,
    String? notes,
    bool? completed,
    DateTime? due,
  }) async {
    return saved = Task(
      id: taskId,
      title: title,
      notes: notes,
      due: due?.toIso8601String(),
    );
  }
}
