import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
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
    'sign in should show login screen when app starts unsigned in',
    (WidgetTester tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        MethodChannel('home_widget'),
        (_) async => null,
      );

      final mock = MockTasksRepository();
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
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);

      final loginResult = await captureAndCompare(
        tester,
        find.byKey(boundaryKey),
        kLoginGoldenPath,
        'login_screen',
      );

      await tester.binding.runAsync(() async {
        await writeReport(
          threshold: kGoldenDiffThreshold,
          screenshots: <String, dynamic>{
            'login_screen': loginResult,
          },
        );
      });

      expect(
        loginResult['pass'] as bool,
        isTrue,
        reason: 'login screen golden diff exceeded threshold',
      );
    },
  );
}
