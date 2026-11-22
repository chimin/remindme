// ignore_for_file: invalid_use_of_visible_for_testing_member

import '../scenario_runner.dart';
import 'package:remindme/main.dart';
import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:provider/provider.dart';

import 'package:remindme/screens/task_edit_screen.dart';
import 'package:remindme/services/tasks_repository.dart';
import 'package:remindme/models/task_metadata.dart';

import '../../../test/screens/golden_test_helper.dart';

ScenarioCases defineScenarios() {
  final scenarios = <String, ScenarioFactory>{};
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

  scenarios['0'] = (state) async {
    final tester = state.tester!;
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      MethodChannel('home_widget'),
      (_) async => null,
    );
    final mock = MockTasksRepository()
      ..taskLists.add(TaskList(id: 'list-1', title: 'Tasks'))
      ..signInMock(tasklistId: 'list-1');
    final boundaryKey = GlobalKey();
    state.next = () async {
      await tester.pumpWidget(
        ChangeNotifierProvider<TasksRepository>.value(
          value: mock,
          child: RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: createAppTheme(),
              home: TaskEditScreen(taskListId: 'list-1'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      state.next = () async {
        expect(find.text('New task'), findsOneWidget);
        expect(find.byType(TextFormField), findsOneWidget);
        expect(find.byTooltip('Save task'), findsOneWidget);
        expect(find.byType(FilledButton), findsNothing);
        expect(find.text('This task is completed'), findsNothing);
        await expectLater(
          find.byKey(boundaryKey),
          matchesGoldenFile(
            '../../features/screenshots/task_edit_screen/task_edit_screen_when_displayed.png',
          ),
        );
      };
    };
  };

  Future<void> pumpEditor(
    WidgetTester tester,
    RecordingTasksRepository repo, {
    Task? task,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<TasksRepository>.value(
        value: repo,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: createAppTheme(),
          home: RepaintBoundary(
            key: const ValueKey('editor'),
            child: TaskEditScreen(taskListId: 'list-1', task: task),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<RecordingTasksRepository> openDeleteEditor(
    WidgetTester tester, {
    bool completed = false,
  }) async {
    final repo = RecordingTasksRepository();
    await tester.pumpWidget(
      ChangeNotifierProvider<TasksRepository>.value(
        value: repo,
        child: RepaintBoundary(
          key: const ValueKey('delete-editor-screen'),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: createAppTheme(),
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TaskEditScreen(
                        taskListId: 'list-1',
                        task: Task(
                          id: 'task-1',
                          status: completed ? 'completed' : 'needsAction',
                          title: 'Water plants',
                          notes: 'Keep soil moist',
                        ),
                      ),
                    ),
                  ),
                  child: const Text('Open editor'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> openDeleteDialog(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Delete task'));
    await tester.pumpAndSettle();
  }

  scenarios['1'] = (state) async {
    final tester = state.tester!;
    state.next = () async {
      final repo = await openDeleteEditor(tester);
      await openDeleteDialog(tester);
      state.next = () async {
        expect(find.text('Delete task?'), findsOneWidget);
        expect(repo.deleted, isEmpty);
        await expectLater(
          find.byKey(const ValueKey('delete-editor-screen')),
          matchesGoldenFile(
            '../../features/screenshots/task_edit_screen/task_edit_screen_when_delete_confirmation.png',
          ),
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
      };
    };
  };

  scenarios['2'] = (state) async {
    final tester = state.tester!;
    final repo = await openDeleteEditor(tester);
    state.next = () async {
      await tester.enterText(
        find.byKey(const ValueKey('task_title')),
        'Changed title',
      );
      await openDeleteDialog(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      state.next = () async {
        expect(find.text('Edit task'), findsOneWidget);
        expect(find.text('Changed title'), findsOneWidget);
        expect(find.text('Keep soil moist'), findsOneWidget);
        expect(repo.deleted, isEmpty);
      };
    };
  };

  scenarios['3'] = (state) async {
    final tester = state.tester!;
    final repo = await openDeleteEditor(tester);
    await openDeleteDialog(tester);
    state.next = () async {
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      state.next = () async {
        expect(repo.deleted, [('list-1', 'task-1')]);
        expect(find.text('Open editor'), findsOneWidget);
        expect(find.text('Edit task'), findsNothing);
      };
    };
  };

  scenarios['4'] = (state) async {
    final tester = state.tester!;
    final repo = await openDeleteEditor(tester);
    repo.pendingDeletion = Completer<void>();
    await openDeleteDialog(tester);
    state.next = () async {
      await tester.tap(find.text('Delete'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      state.next = () async {
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton && widget.tooltip == 'Delete task',
                ),
              )
              .onPressed,
          isNull,
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(repo.deleted, [('list-1', 'task-1')]);
        repo.pendingDeletion!.complete();
        await tester.pumpAndSettle();
      };
    };
  };

  scenarios['5'] = (state) async {
    final tester = state.tester!;
    final repo = await openDeleteEditor(tester);
    repo.deletionError = StateError('offline');
    await openDeleteDialog(tester);
    state.next = () async {
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      state.next = () async {
        expect(find.text('Edit task'), findsOneWidget);
        expect(
          find.text('Failed to delete task: Bad state: offline'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton && widget.tooltip == 'Delete task',
                ),
              )
              .onPressed,
          isNotNull,
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
        expect(repo.deleted, [('list-1', 'task-1')]);
      };
    };
  };

  scenarios['6'] = (state) async {
    final tester = state.tester!;
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
    state.next = () async {
      await pumpEditor(tester, repo, task: task);
      final notes = tester.widget<TextField>(find.byType(TextField).last);
      state.next = () async {
        expect(notes.controller!.text, 'Keep the soil moist');
        expect(find.text('Monthly'), findsOneWidget);
        await expectLater(
          find.byKey(const ValueKey('editor')),
          matchesGoldenFile(
            '../../features/screenshots/task_edit_screen/task_edit_screen_when_repeat.png',
          ),
        );
        state.next = () async {
          await tester.tap(find.byTooltip('Save task'));
          await tester.pumpAndSettle();
          final saved = TaskMetadata.parse(repo.saved!.notes);
          state.next = () async {
            expect(saved.data['futureFeature'], {'color': 'green'});
            expect(saved.data['recurrence'], {
              'frequency': 'monthly',
              'interval': 2,
              'anchorDay': 31,
              'futureRule': true,
            });
          };
        };
      };
    };
  };

  scenarios['7'] = (state) async {
    final tester = state.tester!;
    final repo = RecordingTasksRepository();
    state.next = () async {
      await pumpEditor(tester, repo);
      await tester.enterText(find.byType(TextFormField), 'Water plants');
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Daily').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Save task'));
      await tester.pumpAndSettle();
      state.next = () async {
        expect(
          find.text('Choose a due date for repeating tasks'),
          findsOneWidget,
        );
        expect(repo.saved, isNull);
      };
    };
  };

  scenarios['8'] = (state) async {
    final tester = state.tester!;
    final repo = RecordingTasksRepository();
    state.next = () async {
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
      await tester.tap(find.byTooltip('Save task'));
      await tester.pumpAndSettle();
      final saved = TaskMetadata.parse(repo.saved!.notes);
      state.next = () async {
        expect(saved.data.containsKey('recurrence'), isFalse);
        expect(saved.data['futureFeature'], 123);
        expect(saved.notes, 'Notes');
      };
    };
  };

  scenarios['9'] = (state) async {
    final tester = state.tester!;
    final repo = RecordingTasksRepository();
    final rule = {'frequency': 'future-frequency', 'setting': true};
    state.next = () async {
      await pumpEditor(
        tester,
        repo,
        task: Task(
          id: 'task',
          title: 'Water plants',
          notes: TaskMetadata('Notes', {'recurrence': rule}).encode(),
        ),
      );
      await tester.tap(find.byTooltip('Save task'));
      await tester.pumpAndSettle();
      state.next = () async {
        expect(TaskMetadata.parse(repo.saved!.notes).data['recurrence'], rule);
      };
    };
  };

  scenarios['10'] = (state) async {
    final tester = state.tester!;
    final repo = RecordingTasksRepository();
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    addTearDown(tester.view.resetViewInsets);
    state.next = () async {
      await pumpEditor(tester, repo);
      await tester.enterText(find.byType(TextFormField), 'Water plants');
      await tester.ensureVisible(find.byTooltip('Save task'));
      await tester.tap(find.byTooltip('Save task'));
      await tester.pumpAndSettle();
      state.next = () async {
        expect(tester.takeException(), isNull);
        expect(repo.saved!.title, 'Water plants');
      };
    };
  };
  scenarios['11'] = (state) async {
    final tester = state.tester!;
    final repo = RecordingTasksRepository();
    state.next = () async {
      await pumpEditor(
        tester,
        repo,
        task: Task(id: 'task', title: 'Water plants'),
      );
      final field = find.byKey(const ValueKey('due_date_field'));
      final titleField = find.byType(TextFormField);
      final repeatField = find.byType(DropdownButtonFormField<String>);
      state.next = () async {
        expect(
          tester.getSize(field).height,
          closeTo(tester.getSize(titleField).height, 1),
        );
        expect(
          tester.getSize(field).height,
          closeTo(tester.getSize(repeatField).height, 1),
        );
        for (final offset in [const Offset(8, 8), const Offset(100, 32)]) {
          await tester.tapAt(tester.getTopLeft(field) + offset);
          await tester.pumpAndSettle();
          expect(find.byType(DatePickerDialog), findsOneWidget);
          await tester.tap(find.text('Cancel'));
          await tester.pumpAndSettle();
        }
        state.next = () async {
          await tester.tap(find.text('No due date'));
          await tester.pumpAndSettle();
          state.next = () async {
            expect(find.byType(DatePickerDialog), findsOneWidget);
            state.next = () async {
              await tester.tap(find.text('OK'));
              await tester.pumpAndSettle();
              state.next = () async {
                expect(find.text('Today'), findsOneWidget);
                expect(
                  tester.getSize(field).height,
                  closeTo(tester.getSize(titleField).height, 1),
                );
                state.next = () async {
                  await tester.tap(find.byTooltip('Clear due date'));
                  await tester.pumpAndSettle();
                  state.next = () async {
                    expect(find.text('No due date'), findsOneWidget);
                    expect(find.byType(DatePickerDialog), findsNothing);
                    state.next = () async {
                      await tester.tap(find.byTooltip('Save task'));
                      await tester.pumpAndSettle();
                      state.next = () async {
                        expect(repo.saved!.due, isNull);
                      };
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  scenarios['12'] = (state) async {
    final tester = state.tester!;
    final repo = RecordingTasksRepository();
    state.next = () async {
      await pumpEditor(
        tester,
        repo,
        task: Task(id: 'task', title: 'Water plants'),
      );
      final actions = tester.widget<AppBar>(find.byType(AppBar)).actions!;
      state.next = () async {
        expect(
          actions.whereType<IconButton>().map((button) => button.tooltip),
          ['Delete task', 'Save task'],
        );
        expect(find.text('Mark as completed'), findsOneWidget);
        await expectLater(
          find.byKey(const ValueKey('editor')),
          matchesGoldenFile(
            '../../features/screenshots/task_edit_screen/task_edit_screen_when_incomplete.png',
          ),
        );
      };
    };
  };

  scenarios['13'] = (state) async {
    final tester = state.tester!;
    final repo = RecordingTasksRepository();
    state.next = () async {
      await pumpEditor(
        tester,
        repo,
        task: Task(
          id: 'task',
          title: 'Water plants',
          notes: 'Keep soil moist',
          due: '2030-01-01T00:00:00Z',
          status: 'completed',
        ),
      );
      state.next = () async {
        expect(find.byTooltip('Save task'), findsNothing);
        expect(find.byTooltip('Delete task'), findsOneWidget);
        expect(find.text('Mark as incomplete'), findsOneWidget);
        expect(find.text('View task'), findsOneWidget);
        expect(find.text('This task is completed'), findsOneWidget);
        expect(
          tester
              .getSize(find.byKey(const ValueKey('completed_task_badge')))
              .width,
          tester.getSize(find.byKey(const ValueKey('task_title'))).width,
        );
        expect(
          tester
              .widget<TextField>(
                find.descendant(
                  of: find.byType(TextFormField),
                  matching: find.byType(TextField),
                ),
              )
              .readOnly,
          isTrue,
        );
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('task_notes')))
              .readOnly,
          isTrue,
        );
        expect(
          tester
              .widget<DropdownButtonFormField<String>>(
                find.byType(DropdownButtonFormField<String>),
              )
              .onChanged,
          isNull,
        );
        expect(find.byTooltip('Clear due date'), findsNothing);
        state.next = () async {
          await tester.tap(find.byKey(const ValueKey('due_date_field')));
          await tester.pumpAndSettle();
          state.next = () async {
            expect(find.byType(DatePickerDialog), findsNothing);
            await expectLater(
              find.byKey(const ValueKey('editor')),
              matchesGoldenFile(
                '../../features/screenshots/task_edit_screen/task_edit_screen_when_completed.png',
              ),
            );
          };
        };
      };
    };
  };

  scenarios['14'] = (state) async {
    final tester = state.tester!;
    final repo = await openDeleteEditor(tester);
    state.next = () async {
      await tester.enterText(
        find.byKey(const ValueKey('task_title')),
        'Changed title',
      );
      await tester.enterText(
        find.byKey(const ValueKey('task_notes')),
        'Changed notes',
      );
      await tester.tap(find.text('Mark as completed'));
      await tester.pumpAndSettle();
      state.next = () async {
        expect(repo.saved!.title, 'Changed title');
        expect(TaskMetadata.parse(repo.saved!.notes).notes, 'Changed notes');
        expect(repo.saved!.status, 'completed');
        expect(find.text('Open editor'), findsOneWidget);
        expect(find.byType(TaskEditScreen), findsNothing);
      };
    };
  };

  scenarios['15'] = (state) async {
    final tester = state.tester!;
    state.next = () async {
      final repo = await openDeleteEditor(tester, completed: true);
      state.next = () async {
        expect(find.text('View task'), findsOneWidget);
        state.next = () async {
          await tester.tap(find.text('Mark as incomplete'));
          await tester.pumpAndSettle();
          state.next = () async {
            expect(repo.completionCalls, [('list-1', 'task-1', false)]);
            expect(repo.saved, isNull);
            expect(find.byType(TaskEditScreen), findsOneWidget);
            expect(find.text('Water plants'), findsOneWidget);
            expect(find.text('Keep soil moist'), findsOneWidget);
            expect(find.byTooltip('Save task'), findsOneWidget);
            expect(find.text('Mark as completed'), findsOneWidget);
            expect(find.text('Edit task'), findsOneWidget);
            expect(find.text('View task'), findsNothing);
            expect(find.text('This task is completed'), findsNothing);
            expect(
              tester
                  .widget<TextField>(
                    find.descendant(
                      of: find.byType(TextFormField),
                      matching: find.byType(TextField),
                    ),
                  )
                  .readOnly,
              isFalse,
            );
            state.next = () async {
              await tester.enterText(
                find.byKey(const ValueKey('task_title')),
                'Now editable',
              );
              await tester.tap(find.byTooltip('Save task'));
              await tester.pumpAndSettle();
              state.next = () async {
                expect(repo.saved!.title, 'Now editable');
                expect(repo.saved!.status, 'needsAction');
              };
            };
          };
        };
      };
    };
  };

  scenarios['16'] = (state) async {
    final tester = state.tester!;
    final repo = await openDeleteEditor(tester);
    state.next = () async {
      await tester.enterText(find.byKey(const ValueKey('task_title')), ' ');
      await tester.tap(find.text('Mark as completed'));
      await tester.pumpAndSettle();
      state.next = () async {
        expect(find.text('Title is required'), findsOneWidget);
        expect(repo.saved, isNull);
        expect(find.byType(TaskEditScreen), findsOneWidget);
      };
    };
  };

  scenarios['17'] = (state) async {
    final tester = state.tester!;
    final repo = RecordingTasksRepository();
    state.next = () async {
      await pumpEditor(
        tester,
        repo,
        task: Task(id: 'task', title: '', status: 'completed'),
      );
      await tester.tap(find.text('Mark as incomplete'));
      await tester.pumpAndSettle();
      state.next = () async {
        expect(repo.completionCalls, [('list-1', 'task', false)]);
        expect(find.text('Title is required'), findsNothing);
        expect(find.text('Mark as completed'), findsOneWidget);
      };
    };
  };

  scenarios['18'] = (state) async {
    final tester = state.tester!;
    final repo = await openDeleteEditor(tester, completed: true);
    repo.saveError = StateError('offline');
    state.next = () async {
      await tester.tap(find.text('Mark as incomplete'));
      await tester.pumpAndSettle();
      state.next = () async {
        expect(
          find.text('Failed to mark task as incomplete: Bad state: offline'),
          findsOneWidget,
        );
        expect(find.byTooltip('Save task'), findsNothing);
        expect(
          tester
              .widget<TextField>(
                find.descendant(
                  of: find.byType(TextFormField),
                  matching: find.byType(TextField),
                ),
              )
              .readOnly,
          isTrue,
        );
        expect(find.text('Mark as incomplete'), findsOneWidget);
        expect(find.text('View task'), findsOneWidget);
      };
    };
  };

  scenarios['19'] = (state) async {
    final tester = state.tester!;
    state.next = () async {
      final repo = await openDeleteEditor(tester);
      repo.pendingSave = Completer<void>();
      final callback = tester
          .widget<FilledButton>(find.byType(FilledButton))
          .onPressed!;
      callback();
      callback();
      await tester.pump();
      state.next = () async {
        expect(repo.saveCalls, 1);
        for (final tooltip in ['Save task', 'Delete task']) {
          expect(
            tester
                .widget<IconButton>(
                  find.byWidgetPredicate(
                    (widget) =>
                        widget is IconButton && widget.tooltip == tooltip,
                  ),
                )
                .onPressed,
            isNull,
          );
        }
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNull,
        );
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        state.next = () async {
          repo.pendingSave!.complete();
          await tester.pumpAndSettle();
          state.next = () async {
            expect(find.byType(TaskEditScreen), findsNothing);
          };
        };
      };
    };
  };

  scenarios['20'] = (state) async {
    final tester = state.tester!;
    final repo = await openDeleteEditor(tester);
    repo.saveError = StateError('offline');
    state.next = () async {
      await tester.enterText(
        find.byKey(const ValueKey('task_title')),
        'Keep my changes',
      );
      await tester.tap(find.text('Mark as completed'));
      await tester.pumpAndSettle();
      state.next = () async {
        expect(find.text('Keep my changes'), findsOneWidget);
        expect(
          find.text('Failed to save task: Bad state: offline'),
          findsOneWidget,
        );
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is IconButton && widget.tooltip == 'Save task',
                ),
              )
              .onPressed,
          isNotNull,
        );
      };
    };
  };

  scenarios['21'] = (state) async {
    final tester = state.tester!;
    final repo = await openDeleteEditor(tester, completed: true);
    await openDeleteDialog(tester);
    state.next = () async {
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      state.next = () async {
        expect(repo.deleted, [('list-1', 'task-1')]);
        expect(find.byType(TaskEditScreen), findsNothing);
      };
    };
  };
  return scenarios;
}

class RecordingTasksRepository extends MockTasksRepository {
  Task? saved;
  int saveCalls = 0;
  Object? saveError;
  Completer<void>? pendingSave;
  final completionCalls = <(String, String, bool)>[];

  @override
  Future<void> completeTask(
    String tasklistId,
    String taskId,
    bool value,
  ) async {
    completionCalls.add((tasklistId, taskId, value));
    if (saveError != null) throw saveError!;
    if (pendingSave != null) await pendingSave!.future;
  }

  final deleted = <(String, String)>[];
  Completer<void>? pendingDeletion;
  Object? deletionError;

  @override
  Future<void> deleteTask(String tasklistId, String taskId) async {
    deleted.add((tasklistId, taskId));
    if (deletionError != null) throw deletionError!;
    if (pendingDeletion != null) await pendingDeletion!.future;
  }

  @override
  Future<Task> createTask(
    String tasklistId, {
    required String title,
    String? notes,
    DateTime? due,
  }) async {
    saveCalls++;
    if (saveError != null) throw saveError!;
    if (pendingSave != null) await pendingSave!.future;
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
    saveCalls++;
    if (saveError != null) throw saveError!;
    if (pendingSave != null) await pendingSave!.future;
    return saved = Task(
      id: taskId,
      status: completed == true ? 'completed' : 'needsAction',
      title: title,
      notes: notes,
      due: due?.toIso8601String(),
    );
  }
}
