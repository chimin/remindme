import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:remindme/models/widget_color_config.dart';
import 'package:remindme/screens/widget_color_config_dialog.dart';
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
    'opening should show text/background/transparency controls',
    (WidgetTester tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        MethodChannel('home_widget'),
        (_) async => null,
      );

      final boundaryKey = GlobalKey();

      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
              fontFamily: 'Roboto',
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (_) => WidgetColorConfigDialog(
                        initial: const WidgetColorConfig(),
                        onSaved: (_) {},
                      ),
                    ),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      tester.view.devicePixelRatio = 2.0;
      tester.view.physicalSize = const Size(720, 1280);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      final result = await captureAndCompare(
        tester,
        find.byKey(boundaryKey),
        kWidgetColorConfigGoldenPath,
        'widget_color_config_dialog',
      );

      await tester.binding.runAsync(() async {
        await writeReport(
          threshold: kGoldenDiffThreshold,
          screenshots: <String, dynamic>{
            'widget_color_config_dialog': result,
          },
        );
      });

      expect(
        result['pass'] as bool,
        isTrue,
        reason: 'widget color config dialog golden diff exceeded threshold',
      );
    },
  );
}
