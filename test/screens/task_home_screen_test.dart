import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:provider/provider.dart';

import 'package:remindme/main.dart';
import 'package:remindme/services/tasks_repository.dart';

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
    'home screen should show 6 tasks 2 overdue 2 today 2 future when signed in',
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
          title: 'Today task 1',
          status: 'needsAction',
          due: today1.toIso8601String(),
        ),
        Task(
          id: '4',
          title: 'Today task 2',
          status: 'completed',
          due: today2.toIso8601String(),
        ),
        Task(
          id: '5',
          title: 'Future task 1',
          status: 'needsAction',
          due: tomorrow1.toIso8601String(),
        ),
        Task(
          id: '6',
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
      expect(find.text('Today task 1'), findsOneWidget);
      expect(find.text('Today task 2'), findsOneWidget);
      expect(find.text('Future task 1'), findsOneWidget);
      expect(find.text('Future task 2'), findsOneWidget);

      final homeResult = await captureAndCompare(
        tester,
        find.byKey(boundaryKey),
        kHomeGoldenPath,
        'home_screen',
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
}
