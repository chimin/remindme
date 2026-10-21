import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:provider/provider.dart';

import 'package:remindme/main.dart';
import 'package:remindme/services/tasks_repository.dart';
import 'package:remindme/widgets/trailing_checked_menu_item.dart';

import 'golden_test_helper.dart';

void main() {
  setUpAll(() async {
    final robotoBytes = await File('test/fonts/roboto-regular.ttf').readAsBytes();
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
        Task(
          id: '3',
          title: 'Task without due date',
          status: 'needsAction',
        ),
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
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
                useMaterial3: true,
                fontFamily: 'Roboto',
              ),
              home: const AuthRouter(),
            ),
          ),
        ),
      );
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(720, 1280);
      await mock.init();
      mock.signInMock(tasklistId: 'list-1');
      await tester.pumpAndSettle();

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Overdue task 1'), findsOneWidget);
      expect(find.text('Overdue task 2'), findsOneWidget);
      expect(find.text('No due date'), findsOneWidget);
      expect(find.text('Task without due date'), findsOneWidget);
      expect(find.text('Today task 1'), findsOneWidget);
      expect(find.text('Today task 2'), findsOneWidget);
      expect(find.text('Future task 1'), findsOneWidget);

      // The last task falls below the fold of the 640px tall viewport, so the
      // list has to be scrolled before it is built and can be asserted.
      final scrollable = tester.state<ScrollableState>(
        find.byType(Scrollable).first,
      );
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.text('Future task 2'), findsOneWidget);

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
          screenshots: <String, dynamic>{
            'home_screen': homeResult,
          },
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
    'hide completed tasks should remove completed items when toggle is tapped',
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
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
              fontFamily: 'Roboto',
            ),
            home: const AuthRouter(),
          ),
        ),
      );
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(720, 1280);
      await mock.init();
      mock.signInMock(tasklistId: 'list-1');
      await tester.pumpAndSettle();

      expect(find.text('Completed task'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byWidgetPredicate((w) => w is TrailingCheckedMenuItem),
      );
      await tester.pumpAndSettle();

      expect(find.text('Completed task'), findsNothing);
      expect(find.text('Open task'), findsOneWidget);
      expect(mock.showCompleted, isFalse);
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
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
                useMaterial3: true,
                fontFamily: 'Roboto',
              ),
              home: const AuthRouter(),
            ),
          ),
        ),
      );
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(720, 1280);
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
          screenshots: <String, dynamic>{
            'sign_out_dialog': signOutResult,
          },
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
              theme: ThemeData(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
                useMaterial3: true,
                fontFamily: 'Roboto',
              ),
              home: const AuthRouter(),
            ),
          ),
        ),
      );
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(720, 1280);
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
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
              fontFamily: 'Roboto',
            ),
            home: const AuthRouter(),
          ),
        ),
      );
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(720, 1280);
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
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
              fontFamily: 'Roboto',
            ),
            home: const AuthRouter(),
          ),
        ),
      );
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(720, 1280);
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
    'overflow menu should open at the same height as the task list menu',
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
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
              fontFamily: 'Roboto',
            ),
            home: const AuthRouter(),
          ),
        ),
      );
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(720, 1280);
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
            find.byWidgetPredicate((w) => w is TrailingCheckedMenuItem).first,
          )
          .dy;

      expect(overflowMenuTop, taskListMenuTop);
    },
  );

  testWidgets(
    'overflow menu should show all actions and match the golden screenshot',
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
        ..mockTasks.addAll(tasks);

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
              home: const AuthRouter(),
            ),
          ),
        ),
      );
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(720, 1280);
      await mock.init();
      mock.signInMock(tasklistId: 'list-1');
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.more_vert));
      await tester.pumpAndSettle();

      expect(find.text('Show completed tasks'), findsOneWidget);
      expect(find.text('Widget colors'), findsOneWidget);
      expect(find.text('Delete completed tasks'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byIcon(Icons.done)).dx,
        greaterThan(tester.getTopRight(find.text('Show completed tasks')).dx),
      );

      final menuResult = await captureAndCompare(
        tester,
        find.byKey(boundaryKey),
        kTaskHomeMenuGoldenPath,
        'task_home_screen_menu',
      );

      await tester.binding.runAsync(() async {
        await writeReport(
          threshold: kGoldenDiffThreshold,
          screenshots: <String, dynamic>{
            'task_home_screen_menu': menuResult,
          },
        );
      });

      expect(
        menuResult['pass'] as bool,
        isTrue,
        reason: 'home screen menu golden diff exceeded threshold',
      );
    },
  );
}
