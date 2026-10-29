import 'package:remindme/main.dart';
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

  Future<WidgetColorConfig?> openDialog(
    WidgetTester tester, {
    WidgetColorConfig initial = const WidgetColorConfig(),
  }) async {
    WidgetColorConfig? saved;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: createAppTheme(),
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
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    return saved;
  }

  testWidgets(
    'opening should show color and opacity controls when the dialog opens',
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
      expect(find.textContaining('Background opacity:'), findsOneWidget);
      expect(find.text('Theme'), findsNothing);
      expect(find.byType(ChoiceChip), findsNothing);
      final reset = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Reset'),
      );
      final cancel = tester.getRect(
        find.widgetWithText(OutlinedButton, 'Cancel'),
      );
      final save = tester.getRect(
        find.widgetWithText(FilledButton, 'Save appearance'),
      );
      expect(reset.center.dy, cancel.center.dy);
      expect(save.bottom, lessThan(reset.top));
      expect(reset.width, cancel.width);
      expect(save.left, reset.left);
      expect(save.right, cancel.right);
    },
  );

  testWidgets(
    'tapping a color box should open the color picker when a color is edited',
    (WidgetTester tester) async {
      final messenger = tester.binding.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(
        MethodChannel('home_widget'),
        (_) async => null,
      );

      await openDialog(tester);

      await tester.ensureVisible(
        find.byKey(const ValueKey('color_box_Text color')),
      );
      await tester.tap(find.byKey(const ValueKey('color_box_Text color')));
      await tester.pumpAndSettle();

      expect(find.byType(ColorPicker), findsOneWidget);
      expect(find.text('OK'), findsOneWidget);
    },
  );

  testWidgets(
    'color picker dialog should match the golden screenshot when opened',
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
            debugShowCheckedModeBanner: false,
            theme: createAppTheme(),
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
          screenshots: <String, dynamic>{'widget_color_picker_dialog': result},
        );
      });

      expect(
        result['pass'] as bool,
        isTrue,
        reason: 'widget color picker dialog golden diff exceeded threshold',
      );
    },
  );

  testWidgets('saving should close the dialog when appearance is saved', (
    WidgetTester tester,
  ) async {
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
          debugShowCheckedModeBanner: false,
          theme: createAppTheme(),
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
        screenshots: <String, dynamic>{'widget_color_config_dialog': result},
      );
    });

    expect(
      result['pass'] as bool,
      isTrue,
      reason: 'widget color config dialog golden diff exceeded threshold',
    );

    await tester.tap(find.text('Save appearance'));
    await tester.pumpAndSettle();

    expect(find.text('Widget appearance'), findsNothing);
  });

  testWidgets('reset should restore defaults when confirmation is accepted', (
    tester,
  ) async {
    WidgetColorConfig? saved;
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: createAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => WidgetColorConfigDialog(
                  initial: const WidgetColorConfig(backgroundAlpha: 100),
                  onSaved: (value) => saved = value,
                ),
              ),
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    tester.widget<Slider>(find.byType(Slider)).onChanged!(100);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();
    expect(find.text('Reset widget appearance?'), findsOneWidget);
    expect(tester.widget<Slider>(find.byType(Slider)).value, 100);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('golden/widget_color_config_reset_confirmation.png'),
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Reset'));
    await tester.pumpAndSettle();
    final preview = tester.widget<Container>(
      find.byKey(const ValueKey('widget_preview')),
    );
    expect(preview.child, isNotNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('golden/widget_color_config_reset.png'),
    );
    await tester.tap(find.text('Save appearance'));
    await tester.pumpAndSettle();
    expect(saved!.backgroundColor, const WidgetColorConfig().backgroundColor);
    expect(saved!.textColor, const WidgetColorConfig().textColor);
    expect(find.byType(WidgetColorConfigDialog), findsNothing);
  });

  testWidgets(
    'appearance should retain saved colors when edits are cancelled',
    (tester) async {
      WidgetColorConfig? saved;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: createAppTheme(),
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<void>(
                  context: context,
                  builder: (_) => WidgetColorConfigDialog(
                    initial: const WidgetColorConfig(),
                    onSaved: (value) => saved = value,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      tester.widget<Slider>(find.byType(Slider)).onChanged!(100);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset'));
      await tester.pumpAndSettle();
      expect(find.text('Reset widget appearance?'), findsOneWidget);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 100);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('golden/widget_color_config_reset_confirmation.png'),
      );
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(tester.widget<Slider>(find.byType(Slider)).value, 100);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(saved, isNull);
    },
  );
}
