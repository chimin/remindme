import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:provider/provider.dart';
import 'package:remindme/main.dart';
import 'package:remindme/screens/task_edit_screen.dart';
import 'package:remindme/services/tasks_repository.dart';

import '../screens/golden_test_helper.dart';

class _NavigationRepository extends MockTasksRepository {
  final tasks = <String, List<Task>>{
    'a': [Task(id: 'same-id', title: 'Task A', status: 'needsAction')],
    'b': [Task(id: 'same-id', title: 'Task B', status: 'needsAction')],
  };
  final refreshes = <String>[];
  final selections = <String>[];
  Completer<List<Task>>? pendingB;
  List<Task>? afterRefresh;
  bool offline = false;

  _NavigationRepository() {
    initialized = true;
    taskLists.addAll([
      TaskList(id: 'a', title: 'List A'),
      TaskList(id: 'b', title: 'List B'),
    ]);
    signInMock(tasklistId: 'a');
  }

  @override
  Future<List<Task>> getCachedTasks(String tasklistId) async {
    if (tasklistId == 'b' && pendingB != null) return pendingB!.future;
    return tasks[tasklistId] ?? [];
  }

  @override
  Future<void> refreshTasks(String tasklistId) async {
    refreshes.add(tasklistId);
    if (offline) throw StateError('offline');
    if (tasklistId == 'b' && afterRefresh != null) tasks['b'] = afterRefresh!;
  }

  @override
  Future<void> selectTasklist(String id) async {
    selections.add(id);
    await super.selectTasklist(id);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const updates = EventChannel('home_widget/updates');
  late MockStreamHandlerEventSink clicks;
  String? initial;
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUpAll(() async {
    for (final entry in {
      'Roboto': 'test/fonts/roboto-regular.ttf',
      'MaterialIcons': 'test/fonts/materialicons-regular.otf',
    }.entries) {
      final bytes = await File(entry.value).readAsBytes();
      await (FontLoader(
        entry.key,
      )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    }
  });
  setUp(() {
    initial = null;
    messenger.setMockMethodCallHandler(const MethodChannel('home_widget'), (
      call,
    ) async {
      if (call.method == 'initiallyLaunchedFromHomeWidget') return initial;
      return true;
    });
    messenger.setMockStreamHandler(
      updates,
      MockStreamHandler.inline(
        onListen: (_, sink) {
          clicks = sink;
        },
      ),
    );
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(
      const MethodChannel('home_widget'),
      null,
    );
    messenger.setMockStreamHandler(updates, null);
  });

  String uri(String list, [String task = 'same-id']) => Uri(
    scheme: 'remindme',
    host: 'task',
    path: '/edit',
    queryParameters: {'taskListId': list, 'taskId': task},
  ).toString();

  Future<void> sendClick(WidgetTester tester, String link) async {
    // The mock platform stream is registered by setUp outside the fake clock.
    await tester.runAsync(() async {
      clicks.success(link);
      await Future<void>.delayed(Duration.zero);
    });
  }

  Future<void> pumpApp(WidgetTester tester, _NavigationRepository repo) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TasksRepository>.value(
        value: repo,
        child: const MyApp(),
      ),
    );
    if (repo.initialized) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
      await tester.pump();
    }
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    });
  }

  testWidgets(
    'widget launch should open its owning task when the app starts cold',
    (tester) async {
      final repo = _NavigationRepository();
      initial = uri('b');
      await pumpApp(tester, repo);
      final editor = tester.widget<TaskEditScreen>(find.byType(TaskEditScreen));
      expect(editor.taskListId, 'b');
      expect(editor.task!.title, 'Task B');
      expect(repo.selectedTasklistId, 'b');
      expect(repo.refreshes.where((id) => id == 'b'), isEmpty);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile(
          '../../features/screenshots/widget_task_editor/widget_task_editor_when_displayed.png',
        ),
      );
    },
  );

  testWidgets(
    'widget tap should discard unsaved edits when another task is tapped',
    (tester) async {
      final repo = _NavigationRepository();
      await pumpApp(tester, repo);
      await sendClick(tester, uri('a'));
      await tester.pump();
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('task_title')),
        'Unsaved changes',
      );
      await sendClick(tester, uri('b'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Unsaved changes'), findsNothing);
      expect(find.text('Task B'), findsOneWidget);
      expect(find.byType(TaskEditScreen, skipOffstage: false), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditScreen), findsNothing);
      expect(find.text('List B'), findsOneWidget);
    },
  );

  testWidgets(
    'widget launch should wait for authentication when startup is not ready',
    (tester) async {
      final repo = _NavigationRepository()..initialized = false;
      await repo.signOut();
      initial = uri('b');
      await pumpApp(tester, repo);
      expect(find.byType(TaskEditScreen), findsNothing);
      repo.initialized = true;
      await repo.signIn();
      await tester.pumpAndSettle();
      expect(
        tester.widget<TaskEditScreen>(find.byType(TaskEditScreen)).task!.title,
        'Task B',
      );
    },
  );

  testWidgets(
    'widget tap should open a read only task when a stale entry is now completed',
    (tester) async {
      final repo = _NavigationRepository();
      repo.tasks['b']!.single.status = 'completed';
      await pumpApp(tester, repo);
      await sendClick(tester, uri('b'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('Mark as incomplete'), findsOneWidget);
      expect(find.byTooltip('Save task'), findsNothing);
    },
  );

  testWidgets(
    'widget tap should open one editor when a launch is delivered twice',
    (tester) async {
      final repo = _NavigationRepository();
      initial = uri('b');
      await pumpApp(tester, repo);
      await sendClick(tester, uri('b'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(repo.selections.where((id) => id == 'b'), hasLength(1));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditScreen, skipOffstage: false), findsNothing);
      await sendClick(tester, uri('b'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.byType(TaskEditScreen), findsOneWidget);
    },
  );

  testWidgets(
    'widget tap should refresh once when the task is missing from cache',
    (tester) async {
      final repo = _NavigationRepository();
      repo.tasks['b'] = [];
      repo.afterRefresh = [Task(id: 'same-id', title: 'Recovered task')];
      await pumpApp(tester, repo);
      await sendClick(tester, uri('b'));
      await tester.pump();
      await tester.pumpAndSettle();
      expect(repo.refreshes.where((id) => id == 'b'), hasLength(1));
      expect(find.text('Recovered task'), findsOneWidget);
    },
  );

  for (final offline in [false, true]) {
    testWidgets(
      'widget tap should explain unavailability when the task is ${offline ? 'offline and uncached' : 'deleted'}',
      (tester) async {
        final repo = _NavigationRepository();
        repo.tasks['b'] = [
          Task(id: 'same-id', title: 'Deleted', deleted: true),
        ];
        await pumpApp(tester, repo);
        repo.offline = offline;
        await sendClick(tester, uri('b'));
        await tester.pump();
        await tester.pumpAndSettle();
        expect(find.byType(TaskEditScreen), findsNothing);
        expect(
          find.text(
            'This task is unavailable. Refresh the task list and try again.',
          ),
          findsOneWidget,
        );
        expect(repo.refreshes.where((id) => id == 'b'), hasLength(1));
        expect(repo.selectedTasklistId, 'a');
      },
    );
  }

  testWidgets('widget tap should prefer the latest task when lookups overlap', (
    tester,
  ) async {
    final repo = _NavigationRepository();
    await pumpApp(tester, repo);
    repo.pendingB = Completer<List<Task>>();
    await sendClick(tester, uri('b'));
    await tester.pump();
    await tester.pump();
    await sendClick(tester, uri('a'));
    await tester.pump();
    repo.pendingB!.complete(repo.tasks['b']!);
    await tester.pumpAndSettle();
    expect(
      tester.widget<TaskEditScreen>(find.byType(TaskEditScreen)).task!.title,
      'Task A',
    );
    expect(repo.selectedTasklistId, 'a');
  });

  testWidgets('widget tap should open Home when the link lacks task identity', (
    tester,
  ) async {
    final repo = _NavigationRepository();
    initial = uri('b');
    await pumpApp(tester, repo);
    await sendClick(tester, 'remindme://task/edit');
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.byType(TaskEditScreen), findsNothing);
    expect(find.text('List B'), findsOneWidget);
  });
}
