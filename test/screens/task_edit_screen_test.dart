import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:provider/provider.dart';

import 'package:remindme/screens/task_edit_screen.dart';
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
    'add task page should show empty form when task list selected',
    (WidgetTester tester) async {
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
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(720, 1280);
      await tester.pumpAndSettle();

      expect(find.text('New Task'), findsOneWidget);
      expect(find.byType(TextFormField), findsOneWidget);
      expect(find.text('Save'), findsOneWidget);

      final addResult = await captureAndCompare(
        tester,
        find.byKey(boundaryKey),
        kTaskEditGoldenPath,
        'task_edit_screen',
      );

      await tester.binding.runAsync(() async {
        await writeReport(
          threshold: kGoldenDiffThreshold,
          screenshots: <String, dynamic>{
            'add_task_screen': addResult,
          },
        );
      });

      expect(
        addResult['pass'] as bool,
        isTrue,
        reason: 'add task screen golden diff exceeded threshold',
      );
    },
  );
}
