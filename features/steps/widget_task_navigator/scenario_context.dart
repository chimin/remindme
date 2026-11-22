// ignore_for_file: invalid_use_of_visible_for_testing_member

import '../scenario_runner.dart';
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

import '../../../test/screens/golden_test_helper.dart';

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

ScenarioCases defineScenarios() {
  final scenarios = <String, ScenarioFactory>{};
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

  scenarios['0'] = (state) async {
    final tester = state.tester!;
    final repo = _NavigationRepository();
    initial = uri('b');
    state.next = () async {
      await pumpApp(tester, repo);
      final editor = tester.widget<TaskEditScreen>(find.byType(TaskEditScreen));
      state.next = () async {
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
      };
    };
  };

  scenarios['1'] = (state) async {
    final tester = state.tester!;
    final repo = _NavigationRepository();
    state.next = () async {
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
      state.next = () async {
        expect(find.text('Unsaved changes'), findsNothing);
        expect(find.text('Task B'), findsOneWidget);
        expect(
          find.byType(TaskEditScreen, skipOffstage: false),
          findsOneWidget,
        );
        state.next = () async {
          await tester.pageBack();
          await tester.pumpAndSettle();
          state.next = () async {
            expect(find.byType(TaskEditScreen), findsNothing);
            expect(find.text('List B'), findsOneWidget);
          };
        };
      };
    };
  };

  scenarios['2'] = (state) async {
    final tester = state.tester!;
    final repo = _NavigationRepository()..initialized = false;
    await repo.signOut();
    initial = uri('b');
    state.next = () async {
      await pumpApp(tester, repo);
      state.next = () async {
        expect(find.byType(TaskEditScreen), findsNothing);
        repo.initialized = true;
        state.next = () async {
          await repo.signIn();
          await tester.pumpAndSettle();
          state.next = () async {
            expect(
              tester
                  .widget<TaskEditScreen>(find.byType(TaskEditScreen))
                  .task!
                  .title,
              'Task B',
            );
          };
        };
      };
    };
  };

  scenarios['3'] = (state) async {
    final tester = state.tester!;
    final repo = _NavigationRepository();
    repo.tasks['b']!.single.status = 'completed';
    state.next = () async {
      await pumpApp(tester, repo);
      await sendClick(tester, uri('b'));
      await tester.pump();
      await tester.pumpAndSettle();
      state.next = () async {
        expect(find.text('Mark as incomplete'), findsOneWidget);
        expect(find.byTooltip('Save task'), findsNothing);
      };
    };
  };

  scenarios['4'] = (state) async {
    final tester = state.tester!;
    final repo = _NavigationRepository();
    initial = uri('b');
    state.next = () async {
      await pumpApp(tester, repo);
      await sendClick(tester, uri('b'));
      await tester.pump();
      await tester.pumpAndSettle();
      state.next = () async {
        expect(repo.selections.where((id) => id == 'b'), hasLength(1));
        state.next = () async {
          await tester.pageBack();
          await tester.pumpAndSettle();
          state.next = () async {
            expect(
              find.byType(TaskEditScreen, skipOffstage: false),
              findsNothing,
            );
            state.next = () async {
              await sendClick(tester, uri('b'));
              await tester.pump();
              await tester.pumpAndSettle();
              state.next = () async {
                expect(find.byType(TaskEditScreen), findsOneWidget);
              };
            };
          };
        };
      };
    };
  };

  scenarios['5'] = (state) async {
    final tester = state.tester!;
    final repo = _NavigationRepository();
    repo.tasks['b'] = [];
    repo.afterRefresh = [Task(id: 'same-id', title: 'Recovered task')];
    state.next = () async {
      await pumpApp(tester, repo);
      await sendClick(tester, uri('b'));
      await tester.pump();
      await tester.pumpAndSettle();
      state.next = () async {
        expect(repo.refreshes.where((id) => id == 'b'), hasLength(1));
        expect(find.text('Recovered task'), findsOneWidget);
      };
    };
  };

  for (final offline in [false, true]) {
    scenarios['6:$offline'] = (state) async {
      final tester = state.tester!;
      final repo = _NavigationRepository();
      repo.tasks['b'] = [Task(id: 'same-id', title: 'Deleted', deleted: true)];
      state.next = () async {
        await pumpApp(tester, repo);
        repo.offline = offline;
        await sendClick(tester, uri('b'));
        await tester.pump();
        await tester.pumpAndSettle();
        state.next = () async {
          expect(find.byType(TaskEditScreen), findsNothing);
          expect(
            find.text(
              'This task is unavailable. Refresh the task list and try again.',
            ),
            findsOneWidget,
          );
          expect(repo.refreshes.where((id) => id == 'b'), hasLength(1));
          expect(repo.selectedTasklistId, 'a');
        };
      };
    };
  }

  scenarios['7'] = (state) async {
    final tester = state.tester!;
    final repo = _NavigationRepository();
    state.next = () async {
      await pumpApp(tester, repo);
      repo.pendingB = Completer<List<Task>>();
      await sendClick(tester, uri('b'));
      await tester.pump();
      await tester.pump();
      await sendClick(tester, uri('a'));
      await tester.pump();
      repo.pendingB!.complete(repo.tasks['b']!);
      await tester.pumpAndSettle();
      state.next = () async {
        expect(
          tester
              .widget<TaskEditScreen>(find.byType(TaskEditScreen))
              .task!
              .title,
          'Task A',
        );
        expect(repo.selectedTasklistId, 'a');
      };
    };
  };

  scenarios['8'] = (state) async {
    final tester = state.tester!;
    final repo = _NavigationRepository();
    initial = uri('b');
    state.next = () async {
      await pumpApp(tester, repo);
      await sendClick(tester, 'remindme://task/edit');
      await tester.pump();
      await tester.pumpAndSettle();
      state.next = () async {
        expect(find.byType(TaskEditScreen), findsNothing);
        expect(find.text('List B'), findsOneWidget);
      };
    };
  };
  return scenarios;
}
