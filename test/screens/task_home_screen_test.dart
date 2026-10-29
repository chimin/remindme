import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:provider/provider.dart';

import 'package:remindme/main.dart';
import 'package:remindme/models/task_metadata.dart';
import 'package:remindme/screens/task_home_screen.dart';
import 'package:remindme/services/tasks_repository.dart';
import 'package:remindme/widgets/trailing_checked_menu_item.dart';

import 'golden_test_helper.dart';

class _DeletionRepository extends MockTasksRepository {
  final deletions = [Completer<void>(), Completer<void>()];
  int _nextDeletion = 0;

  @override
  Future<void> deleteTask(String tasklistId, String taskId) async {
    await deletions[_nextDeletion++].future;
    mockTasks.removeWhere((task) => task.id == taskId);
  }
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .implicitView!;
    view.physicalSize = const Size(360, 640);
    view.devicePixelRatio = 1;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);
  });

  for (final variant in [
    'empty',
    'single_task_per_category',
    'multiple_tasks_per_category',
    'mixed_overdue_dates',
    'today_and_tomorrow',
    'future_dates',
    'repeating_tasks_with_notes',
    'long_titles_and_notes',
  ]) {
    testWidgets(
      'listing should match the $variant screenshot when its tasks are loaded',
      (tester) async {
        const channel = MethodChannel('home_widget');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (_) async => null,
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final tomorrow = DateTime(now.year, now.month, now.day + 1);
        final tasks = <Task>[];
        void add(
          String title, {
          DateTime? due,
          String? notes,
          bool done = false,
        }) {
          tasks.add(
            Task(
              id: 'variant-${tasks.length}',
              title: title,
              due: due?.toIso8601String(),
              notes: notes,
              status: done ? 'completed' : 'needsAction',
            ),
          );
        }

        switch (variant) {
          case 'single_task_per_category':
          case 'multiple_tasks_per_category':
            final count = variant == 'single_task_per_category' ? 1 : 2;
            for (var i = 1; i <= count; i++) {
              add('Overdue task $i', due: DateTime(2000, 1, i));
              add('Undated task $i');
              add('Today task $i', due: today);
              add('Tomorrow task $i', due: tomorrow);
              add('Future task $i', due: DateTime(2040, 6, 15));
              add('Completed task $i', due: today, done: true);
            }
            break;
          case 'mixed_overdue_dates':
            add('Return library books', due: DateTime(2000, 1, 10));
            add('Submit expense report', due: DateTime(2000, 1, 12));
            add('Renew membership', due: DateTime(2000, 1, 15));
            break;
          case 'today_and_tomorrow':
            add('Prepare meeting agenda', due: today);
            add('Buy groceries', due: today, notes: 'Milk, bread, and coffee');
            add('Collect parcel', due: tomorrow);
            add('Call the dentist', due: tomorrow);
            break;
          case 'future_dates':
            add('Plan summer holiday', due: DateTime(2040, 6, 15));
            add('Book accommodation', due: DateTime(2040, 6, 15));
            add('Review travel checklist', due: DateTime(2040, 6, 20));
            add('Pack bags', due: DateTime(2040, 7, 1));
            break;
          case 'repeating_tasks_with_notes':
            for (final withDate in [true, false]) {
              for (final withNotes in [true, false]) {
                add(
                  withNotes ? 'Review journal' : 'Take a walk',
                  due: withDate ? DateTime(2000, 1, 10) : today,
                  notes: TaskMetadata(
                    withNotes ? 'Record one highlight from the day.' : '',
                    {
                      'recurrence': {'frequency': 'daily'},
                    },
                  ).encode(),
                );
              }
            }
            break;
          case 'long_titles_and_notes':
            add(
              'Review the complete project proposal and prepare detailed feedback for the planning meeting',
              due: today,
              notes:
                  'Check the timeline, budget, dependencies, and outstanding questions. '
                  'Write down the decisions that need input from the whole team before the next review.',
            );
            add(
              'Organize all the documents needed for the upcoming appointment and confirm the arrangements',
              due: tomorrow,
              notes:
                  'Bring identification and the completed forms.\n'
                  'Confirm the address and arrival time.\n'
                  'Leave enough time for the journey.',
            );
            break;
        }
        final repo = MockTasksRepository()
          ..taskLists.add(TaskList(id: 'list-1', title: 'Tasks'))
          ..mockTasks.addAll(tasks)
          ..signInMock(tasklistId: 'list-1');
        await tester.pumpWidget(
          ChangeNotifierProvider<TasksRepository>.value(
            value: repo,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: createAppTheme(),
              home: const TaskHomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('golden/task_home_screen_$variant.png'),
        );
      },
    );
  }

  for (final save in [true, false]) {
    testWidgets(
      'widget appearance should ${save ? 'save settings before refreshing' : 'keep settings unchanged'} when edits are ${save ? 'saved' : 'cancelled'}',
      (tester) async {
        final calls = <MethodCall>[];
        final saved = Completer<bool>();
        const channel = MethodChannel('home_widget');
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          (call) async {
            calls.add(call);
            if (call.method == 'saveWidgetData' &&
                (call.arguments as Map)['id'] == 'task_widget_config') {
              return saved.future;
            }
            if (call.method == 'getWidgetData') return null;
            return true;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            channel,
            null,
          ),
        );
        final repo = MockTasksRepository()
          ..taskLists.add(TaskList(id: 'list-1', title: 'Tasks'))
          ..mockTasks.add(Task(id: 'open', title: 'Open task'))
          ..signInMock(tasklistId: 'list-1');
        await tester.pumpWidget(
          ChangeNotifierProvider<TasksRepository>.value(
            value: repo,
            child: MaterialApp(
              theme: createAppTheme(),
              home: const TaskHomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.more_vert));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Widget appearance'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Dark'));
        await tester.pumpAndSettle();
        calls.clear();
        await tester.tap(find.text(save ? 'Save appearance' : 'Cancel'));
        await tester.pumpAndSettle();
        if (save) {
          expect(calls.map((call) => call.method), ['saveWidgetData']);
          expect(
            (calls.single.arguments as Map)['data'],
            contains('4280754481'),
          );
          saved.complete(true);
          await tester.pumpAndSettle();
          expect(calls.map((call) => call.method), [
            'saveWidgetData',
            'updateWidget',
          ]);
        } else {
          expect(calls, isEmpty);
        }
        expect(find.text('Widget appearance'), findsNothing);
      },
    );
  }
  testWidgets(
    'delete completed tasks should show progress popup over listing when deletion is in progress',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('home_widget'),
        (_) async => null,
      );
      final repo = _DeletionRepository()
        ..taskLists.add(TaskList(id: 'list-1', title: 'Tasks'))
        ..mockTasks.addAll([
          Task(id: 'one', title: 'First', status: 'completed'),
          Task(id: 'two', title: 'Second', status: 'completed'),
          Task(id: 'three', title: 'Active', status: 'needsAction'),
        ])
        ..signInMock(tasklistId: 'list-1');
      await tester.pumpWidget(
        ChangeNotifierProvider<TasksRepository>.value(
          value: repo,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: createAppTheme(),
            home: const TaskHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete completed tasks'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete 2 tasks'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('0 of 2 deleted'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      expect(find.text('Active'), findsOneWidget);
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      expect(find.byType(AlertDialog), findsOneWidget);
      repo.deletions[0].complete();
      await tester.pump();
      expect(find.text('1 of 2 deleted'), findsOneWidget);
      final screenshot = await captureAndCompare(
        tester,
        find.byType(MaterialApp),
        'test/screens/golden/task_home_screen_delete_progress_popup.png',
        'Delete completed tasks progress',
      );
      expect(screenshot['pass'], isTrue);
      repo.deletions[1].complete();
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Active'), findsOneWidget);
      expect(repo.mockTasks.map((task) => task.id), ['three']);
      expect(find.text('Completed'), findsNothing);
      expect(find.byTooltip('Delete completed tasks'), findsNothing);
    },
  );
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

  testWidgets(
    'home screen should hide metadata when repeating tasks are listed',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('home_widget'),
        (_) async => null,
      );
      final notes = TaskMetadata('User notes', {
        'recurrence': {'frequency': 'daily'},
        'operationId': 'repeat:list:old',
      }).encode();
      final repo = MockTasksRepository()
        ..taskLists.add(TaskList(id: 'list-1', title: 'Tasks'))
        ..mockTasks.addAll([
          Task(
            id: 'old',
            title: 'Repeating task',
            notes: notes,
            due: '2030-01-01T00:00:00Z',
          ),
          Task(
            title: 'Pending repeat',
            notes: notes,
            due: '2030-01-02T00:00:00Z',
          ),
        ])
        ..signInMock(tasklistId: 'list-1');
      await tester.pumpWidget(
        ChangeNotifierProvider<TasksRepository>.value(
          value: repo,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: createAppTheme(),
            home: const TaskHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('User notes'), findsNWidgets(2));
      expect(find.textContaining('[remindme:'), findsNothing);
      expect(find.byIcon(Icons.repeat), findsNWidgets(2));
      expect(find.text('daily'), findsNWidgets(2));
      expect(find.textContaining('Repeats daily'), findsNothing);
      for (final icon in tester.widgetList<Icon>(find.byIcon(Icons.repeat))) {
        expect(icon.size, 14);
      }
      for (final tile in tester.widgetList<ListTile>(find.byType(ListTile))) {
        expect(tile.trailing, isNull);
      }
      expect(
        tester.getTopLeft(find.text('User notes').first).dy,
        lessThan(tester.getTopLeft(find.text('daily').first).dy),
      );
      await tester.tap(find.text('Pending repeat'));
      await tester.pumpAndSettle();
      expect(find.text('Edit task'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'home screen should show 7 tasks 2 overdue 1 no due date 2 today 2 future '
    'when signed in',
    (WidgetTester tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        MethodChannel('home_widget'),
        (_) async => null,
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final overdue1 = today.subtract(const Duration(days: 2));
      final overdue2 = today.subtract(const Duration(days: 5));
      final today1 = today;
      final today2 = today.add(const Duration(hours: 3));
      final tomorrow1 = today.add(const Duration(days: 1));
      final tomorrow2 = today.add(const Duration(days: 4));

      final tasks = <Task>[
        Task(
          id: '1',
          title: 'Overdue task 1',
          status: 'needsAction',
          due: overdue1.toIso8601String(),
        ),
        Task(
          id: '2',
          title: 'Overdue task 2',
          status: 'needsAction',
          due: overdue2.toIso8601String(),
        ),
        Task(id: '3', title: 'Task without due date', status: 'needsAction'),
        Task(
          id: '4',
          title: 'Today task 1',
          status: 'needsAction',
          due: today1.toIso8601String(),
        ),
        Task(
          id: '5',
          title: 'Today task 2',
          status: 'completed',
          due: today2.toIso8601String(),
        ),
        Task(
          id: '6',
          title: 'Future task 1',
          status: 'needsAction',
          due: tomorrow1.toIso8601String(),
        ),
        Task(
          id: '7',
          title: 'Future task 2',
          status: 'needsAction',
          due: tomorrow2.toIso8601String(),
        ),
      ];

      final mock = MockTasksRepository()
        ..taskLists.add(TaskList(id: 'list-1', title: 'Tasks'))
        ..mockTasks.addAll(tasks);

      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        ChangeNotifierProvider<TasksRepository>.value(
          value: mock,
          child: RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: createAppTheme(),
              home: const AuthRouter(),
            ),
          ),
        ),
      );
      await mock.init();
      mock.signInMock(tasklistId: 'list-1');
      await tester.pumpAndSettle();

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Overdue task 1'), findsOneWidget);
      expect(find.text('Overdue task 2'), findsOneWidget);
      expect(find.text('No due date'), findsOneWidget);
      expect(find.text('Task without due date'), findsOneWidget);
      expect(find.text('Today task 1'), findsOneWidget);

      // The last task falls below the fold of the 640px tall viewport, so the
      // list has to be scrolled before it is built and can be asserted.
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('Future task 1'), findsOneWidget);
      expect(find.text('Future task 2'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Today task 2'), findsOneWidget);

      // Scroll back to the top so the golden shows the whole list header.
      scrollable.position.jumpTo(0);
      await tester.pumpAndSettle();

      final homeResult = await captureAndCompare(
        tester,
        find.byKey(boundaryKey),
        kTaskHomeGoldenPath,
        'task_home_screen',
      );

      await tester.binding.runAsync(() async {
        await writeReport(
          threshold: kGoldenDiffThreshold,
          screenshots: <String, dynamic>{'home_screen': homeResult},
        );
      });

      expect(
        homeResult['pass'] as bool,
        isTrue,
        reason: 'home screen golden diff exceeded threshold',
      );
    },
  );

  testWidgets(
    'listing should show completed tasks when the saved visibility setting is false',
    (WidgetTester tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        MethodChannel('home_widget'),
        (_) async => null,
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final tasks = <Task>[
        Task(
          id: '1',
          title: 'Open task',
          status: 'needsAction',
          due: today.toIso8601String(),
        ),
        Task(
          id: '2',
          title: 'Completed task',
          status: 'completed',
          due: today.toIso8601String(),
        ),
      ];

      final mock = MockTasksRepository()
        ..taskLists.add(TaskList(id: 'list-1', title: 'Tasks'))
        ..mockTasks.addAll(tasks);

      await tester.pumpWidget(
        ChangeNotifierProvider<TasksRepository>.value(
          value: mock,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: createAppTheme(),
            home: const AuthRouter(),
          ),
        ),
      );
      await mock.setShowCompleted(false);
      await mock.init();
      mock.signInMock(tasklistId: 'list-1');
      await tester.pumpAndSettle();

      expect(find.text('Completed task'), findsOneWidget);

      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Open task'), findsOneWidget);
      expect(find.byTooltip('Delete completed tasks'), findsOneWidget);
      expect(mock.showCompleted, isFalse);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/task_home_screen_completed.png'),
      );
    },
  );

  testWidgets(
    'sign out confirmation dialog should appear when logout button is tapped',
    (WidgetTester tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        MethodChannel('home_widget'),
        (_) async => null,
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final tasks = <Task>[
        Task(
          id: '1',
          title: 'Completed task',
          status: 'completed',
          due: today.toIso8601String(),
        ),
      ];

      final mock = MockTasksRepository()
        ..taskLists.add(TaskList(id: 'list-1', title: 'Tasks'))
        ..mockTasks.addAll(tasks);

      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        ChangeNotifierProvider<TasksRepository>.value(
          value: mock,
          child: RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: createAppTheme(),
              home: const AuthRouter(),
            ),
          ),
        ),
      );
      await mock.init();
      mock.signInMock(tasklistId: 'list-1');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign out'));
      await tester.pumpAndSettle();

      expect(find.text('Sign out?'), findsOneWidget);

      final signOutResult = await captureAndCompare(
        tester,
        find.byKey(boundaryKey),
        kSignOutDialogGoldenPath,
        'sign_out_dialog',
      );

      await tester.binding.runAsync(() async {
        await writeReport(
          threshold: kGoldenDiffThreshold,
          screenshots: <String, dynamic>{'sign_out_dialog': signOutResult},
        );
      });

      expect(
        signOutResult['pass'] as bool,
        isTrue,
        reason: 'sign out dialog golden diff exceeded threshold',
      );
    },
  );

  testWidgets(
    'task list menu should show available lists when app title is tapped',
    (WidgetTester tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        MethodChannel('home_widget'),
        (_) async => null,
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final tasks = <Task>[
        Task(
          id: '1',
          title: 'Task',
          status: 'needsAction',
          due: today.toIso8601String(),
        ),
      ];

      final mock = MockTasksRepository()
        ..taskLists.add(TaskList(id: 'list-1', title: 'Tasks'))
        ..taskLists.add(TaskList(id: 'list-2', title: 'Personal'))
        ..mockTasks.addAll(tasks);

      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        ChangeNotifierProvider<TasksRepository>.value(
          value: mock,
          child: RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: createAppTheme(),
              home: const AuthRouter(),
            ),
          ),
        ),
      );
      await mock.init();
      mock.signInMock(tasklistId: 'list-1');
      await tester.pumpAndSettle();

      expect(find.text('Tasks'), findsOneWidget);
      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Personal'), findsOneWidget);
      expect(find.byIcon(Icons.done), findsOneWidget);

      final switcherResult = await captureAndCompare(
        tester,
        find.byKey(boundaryKey),
        kTaskHomeListSwitcherGoldenPath,
        'task_home_screen_list_switcher',
      );

      await tester.binding.runAsync(() async {
        await writeReport(
          threshold: kGoldenDiffThreshold,
          screenshots: <String, dynamic>{
            'task_home_screen_list_switcher': switcherResult,
          },
        );
      });

      expect(
        switcherResult['pass'] as bool,
        isTrue,
        reason: 'list switcher golden diff exceeded threshold',
      );
    },
  );

  testWidgets(
    'selecting a task list should switch the selected list when menu item is tapped',
    (WidgetTester tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        MethodChannel('home_widget'),
        (_) async => null,
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final tasks = <Task>[
        Task(
          id: '1',
          title: 'Task',
          status: 'needsAction',
          due: today.toIso8601String(),
        ),
      ];

      final mock = MockTasksRepository()
        ..taskLists.add(TaskList(id: 'list-1', title: 'Tasks'))
        ..taskLists.add(TaskList(id: 'list-2', title: 'Personal'))
        ..mockTasks.addAll(tasks);

      await tester.pumpWidget(
        ChangeNotifierProvider<TasksRepository>.value(
          value: mock,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: createAppTheme(),
            home: const AuthRouter(),
          ),
        ),
      );
      await mock.init();
      mock.signInMock(tasklistId: 'list-1');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TrailingCheckedMenuItem<String>, 'Personal'),
      );
      await tester.pumpAndSettle();

      expect(mock.selectedTasklistId, 'list-2');
      expect(find.text('Personal'), findsOneWidget);
    },
  );

  testWidgets(
    'overflow menu should not open while the task list menu is open',
    (WidgetTester tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        MethodChannel('home_widget'),
        (_) async => null,
      );

      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);

      final tasks = <Task>[
        Task(
          id: '1',
          title: 'Task',
          status: 'needsAction',
          due: today.toIso8601String(),
        ),
      ];

      final mock = MockTasksRepository()
        ..taskLists.add(TaskList(id: 'list-1', title: 'Tasks'))
        ..taskLists.add(TaskList(id: 'list-2', title: 'Personal'))
        ..mockTasks.addAll(tasks);

      await tester.pumpWidget(
        ChangeNotifierProvider<TasksRepository>.value(
          value: mock,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: createAppTheme(),
            home: const AuthRouter(),
          ),
        ),
      );
      await mock.init();
      mock.signInMock(tasklistId: 'list-1');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Personal'), findsOneWidget);

      // The open popup's modal barrier swallows the tap, so the task list menu
      // is dismissed without the overflow menu taking over.
      await tester.tapAt(tester.getCenter(find.byIcon(Icons.more_vert)));
      await tester.pumpAndSettle();

      expect(find.text('Personal'), findsNothing);
      expect(find.text('Sign out'), findsNothing);
    },
  );

  testWidgets(
    'overflow menu should align with the task list menu when opened',
    (WidgetTester tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        MethodChannel('home_widget'),
        (_) async => null,
      );

      final mock = MockTasksRepository()
        ..taskLists.add(TaskList(id: 'list-1', title: 'Tasks'))
        ..taskLists.add(TaskList(id: 'list-2', title: 'Personal'));

      await tester.pumpWidget(
        ChangeNotifierProvider<TasksRepository>.value(
          value: mock,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: createAppTheme(),
            home: const AuthRouter(),
          ),
        ),
      );
      await mock.init();
      mock.signInMock(tasklistId: 'list-1');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Tasks'));
      await tester.pumpAndSettle();
      final taskListMenuTop = tester
          .getTopLeft(find.byType(TrailingCheckedMenuItem<String>).first)
          .dy;
      await tester.tapAt(const Offset(5, 300));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      final overflowMenuTop = tester
          .getTopLeft(
            find.byWidgetPredicate((widget) => widget is PopupMenuItem).first,
          )
          .dy;

      expect(overflowMenuTop, taskListMenuTop);
    },
  );

  testWidgets('overflow menu should show appearance and sign out when opened', (
    WidgetTester tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      MethodChannel('home_widget'),
      (_) async => null,
    );

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final tasks = <Task>[
      Task(
        id: '1',
        title: 'Task',
        status: 'needsAction',
        due: today.toIso8601String(),
      ),
    ];

    final mock = MockTasksRepository()
      ..taskLists.add(TaskList(id: 'list-1', title: 'Tasks'))
      ..mockTasks.addAll(tasks);

    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      ChangeNotifierProvider<TasksRepository>.value(
        value: mock,
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: createAppTheme(),
            home: const AuthRouter(),
          ),
        ),
      ),
    );
    await mock.init();
    mock.signInMock(tasklistId: 'list-1');
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Show completed tasks'), findsNothing);
    expect(find.text('Widget appearance'), findsOneWidget);
    expect(find.text('Delete completed tasks'), findsNothing);
    expect(find.text('Sign out'), findsOneWidget);
    expect(find.byIcon(Icons.done), findsNothing);

    final menuResult = await captureAndCompare(
      tester,
      find.byKey(boundaryKey),
      kTaskHomeMenuGoldenPath,
      'task_home_screen_menu',
    );

    await tester.binding.runAsync(() async {
      await writeReport(
        threshold: kGoldenDiffThreshold,
        screenshots: <String, dynamic>{'task_home_screen_menu': menuResult},
      );
    });

    expect(
      menuResult['pass'] as bool,
      isTrue,
      reason: 'home screen menu golden diff exceeded threshold',
    );
  });

  testWidgets(
    'listing should show all tasks and an icon action when the home screen opens',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('home_widget'),
        (_) async => null,
      );
      final now = DateTime.now();
      final repo = MockTasksRepository()
        ..taskLists.add(TaskList(id: 'list-1', title: 'Tasks'))
        ..mockTasks.addAll([
          Task(
            id: 'past',
            title: 'Past task',
            due: now.subtract(const Duration(days: 1)).toIso8601String(),
          ),
          Task(id: 'today', title: 'Current task', due: now.toIso8601String()),
          Task(
            id: 'future',
            title: 'Later task',
            due: now.add(const Duration(days: 1)).toIso8601String(),
          ),
          Task(id: 'undated', title: 'Undated task'),
        ])
        ..signInMock(tasklistId: 'list-1');
      await tester.pumpWidget(
        ChangeNotifierProvider<TasksRepository>.value(
          value: repo,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: createAppTheme(),
            home: const TaskHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final title in [
        'Past task',
        'Current task',
        'Later task',
        'Undated task',
      ]) {
        expect(find.text(title), findsOneWidget);
      }
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.textContaining(RegExp(r'^\d+ tasks? today$')), findsNothing);
      expect(find.text('Add task'), findsNothing);
      final add = find.byTooltip('Add task');
      expect(add, findsOneWidget);
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .isExtended,
        isFalse,
      );
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.text('New task'), findsOneWidget);
    },
  );

  testWidgets(
    'category bars should limit collapse and counts when all categories are present',
    (tester) async {
      tester.view.physicalSize = const Size(720, 2400);
      addTearDown(tester.view.resetPhysicalSize);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('home_widget'),
        (_) async => null,
      );
      final now = DateTime.now();
      final repo = MockTasksRepository()
        ..taskLists.add(TaskList(id: 'list-1', title: 'Tasks'))
        ..mockTasks.addAll([
          Task(
            id: 'past',
            title: 'Past task',
            due: now.subtract(const Duration(days: 1)).toIso8601String(),
          ),
          Task(id: 'undated', title: 'Undated task'),
          Task(id: 'today', title: 'Current task', due: now.toIso8601String()),
          Task(
            id: 'today-2',
            title: 'Another current task',
            due: now.toIso8601String(),
          ),
          Task(
            id: 'future',
            title: 'Later task',
            due: now.add(const Duration(days: 1)).toIso8601String(),
          ),
          Task(id: 'done', title: 'Finished task', status: 'completed'),
        ])
        ..signInMock(tasklistId: 'list-1');
      await tester.pumpWidget(
        ChangeNotifierProvider<TasksRepository>.value(
          value: repo,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: createAppTheme(),
            home: const TaskHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final category in ['today']) {
        expect(
          find.byKey(ValueKey('category_count_$category')),
          findsOneWidget,
        );
      }
      for (final category in ['overdue', 'noDueDate', 'future', 'completed']) {
        expect(find.byKey(ValueKey('category_count_$category')), findsNothing);
      }
      expect(find.byIcon(Icons.expand_less), findsNWidgets(2));
      for (final title in ['Current task', 'Later task']) {
        final tile = tester.widget<ListTile>(
          find.ancestor(of: find.text(title), matching: find.byType(ListTile)),
        );
        expect(tile.subtitle, isNull);
      }
      final overdueTile = tester.widget<ListTile>(
        find.ancestor(
          of: find.text('Past task'),
          matching: find.byType(ListTile),
        ),
      );
      expect(overdueTile.subtitle, isNotNull);
      for (final entry in {
        'overdue_Overdue': 'Past task',
        'noDueDate_No due date': 'Undated task',
      }.entries) {
        final heading = find.byKey(ValueKey('category_${entry.key}'));
        await tester.tap(heading);
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsNothing);
        await tester.tap(heading);
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
      }
      for (final entry in {
        'today_Today': 'Current task',
        'completed_Completed': 'Finished task',
      }.entries) {
        final heading = find.byKey(ValueKey('category_${entry.key}'));
        expect(
          find.descendant(of: heading, matching: find.byType(InkWell)),
          entry.key == 'completed_Completed' ? findsOneWidget : findsNothing,
        );
        await tester.tap(heading);
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
      }
      final futureHeading = find.byWidgetPredicate(
        (widget) =>
            widget.key is ValueKey<String> &&
            (widget.key! as ValueKey<String>).value.startsWith(
              'category_future_',
            ),
      );
      expect(
        find.descendant(of: futureHeading, matching: find.byType(InkWell)),
        findsNothing,
      );
      await tester.tap(futureHeading);
      await tester.pumpAndSettle();
      expect(find.text('Later task'), findsOneWidget);
    },
  );

  testWidgets(
    'delete confirmation should show the task count when completed tasks exist',
    (tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('home_widget'),
        (_) async => null,
      );
      final repo = MockTasksRepository()
        ..taskLists.add(TaskList(id: 'list-1', title: 'Tasks'))
        ..mockTasks.addAll([
          Task(id: 'done', title: 'Finished task', status: 'completed'),
          Task(id: 'open', title: 'Open task'),
        ])
        ..signInMock(tasklistId: 'list-1');
      await tester.pumpWidget(
        ChangeNotifierProvider<TasksRepository>.value(
          value: repo,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: createAppTheme(),
            home: const TaskHomeScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Delete completed tasks'));
      await tester.pumpAndSettle();
      expect(find.text('Clear 1 completed task?'), findsOneWidget);
      expect(find.text('Delete 1 task'), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/delete_completed_tasks_dialog.png'),
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.mockTasks, hasLength(2));
      expect(find.text('Finished task'), findsOneWidget);
    },
  );
}
