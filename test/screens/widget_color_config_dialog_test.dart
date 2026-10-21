import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:remindme/models/widget_color_config.dart';
import 'package:remindme/screens/widget_color_config_dialog.dart';
import 'package:remindme/widgets/color_picker.dart';

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

  Future<WidgetColorConfig?> openDialog(
    WidgetTester tester, {
    WidgetColorConfig initial = const WidgetColorConfig(),
  }) async {
    WidgetColorConfig? saved;
    await tester.pumpWidget(
      MaterialApp(
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
                    initial: initial,
                    onSaved: (config) => saved = config,
                  ),
                ),
                child: const Text('Open'),
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
    return saved;
  }

  testWidgets(
    'opening should show text/background/transparency controls',
    (WidgetTester tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        MethodChannel('home_widget'),
        (_) async => null,
      );

      await openDialog(tester);

      expect(find.text('Text color'), findsOneWidget);
      expect(find.text('Overdue title color'), findsOneWidget);
      expect(find.text('Background color'), findsOneWidget);
      expect(find.textContaining('Transparency:'), findsOneWidget);
      expect(find.text('Custom'), findsNothing);
    },
  );

  testWidgets(
    'tapping a color box should open the color picker',
    (WidgetTester tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        MethodChannel('home_widget'),
        (_) async => null,
      );

      await openDialog(tester);

      await tester.tap(find.byKey(const ValueKey('color_box_Text color')));
      await tester.pumpAndSettle();

      expect(find.byType(ColorPicker), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    },
  );

  testWidgets(
    'color picker dialog should match the golden screenshot',
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

      await tester.tap(find.byKey(const ValueKey('color_box_Text color')));
      await tester.pumpAndSettle();

      final result = await captureAndCompare(
        tester,
        find.byKey(boundaryKey),
        kWidgetColorPickerDialogGoldenPath,
        'widget_color_picker_dialog',
      );

      await tester.binding.runAsync(() async {
        await writeReport(
          threshold: kGoldenDiffThreshold,
          screenshots: <String, dynamic>{
            'widget_color_picker_dialog': result,
          },
        );
      });

      expect(
        result['pass'] as bool,
        isTrue,
        reason: 'widget color picker dialog golden diff exceeded threshold',
      );
    },
  );

  testWidgets(
    'tapping save should call onSaved and pop dialog',
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

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Widget colors'), findsNothing);
    },
  );
}
