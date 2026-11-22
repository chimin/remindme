import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remindme/main.dart';
import 'package:remindme/screens/reminder_settings_dialog.dart';
import 'package:remindme/services/reminder_service.dart';

import 'golden_test_helper.dart';

void main() {
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
  Future<void> open(
    WidgetTester tester,
    void Function(ReminderSettings?) onResult,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: createAppTheme(),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async => onResult(
                await showDialog<ReminderSettings>(
                  context: context,
                  builder: (_) => const ReminderSettingsDialog(
                    settings: ReminderSettings(),
                  ),
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
  }

  testWidgets('cancel should discard changes when the switch was changed', (
    tester,
  ) async {
    ReminderSettings? saved;
    await open(tester, (result) => saved = result);
    await tester.tap(find.byType(Switch));
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
  });

  testWidgets(
    'save should return edited settings when the switch was changed',
    (tester) async {
      ReminderSettings? saved;
      await open(tester, (result) => saved = result);
      await tester.tap(find.byType(Switch));
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved!.enabled, isFalse);
      expect(saved!.hour, 8);
    },
  );

  testWidgets('display should show the reminder controls when settings open', (
    tester,
  ) async {
    await open(tester, (_) {});
    expect(find.text('Time (24-hour)'), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    // captureImage omits retained switch paint until the control repaints.
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();
    final result = await captureAndCompare(
      tester,
      find.byType(MaterialApp),
      'screenshots/reminder_settings_dialog/reminder_settings_dialog_when_displayed.png',
      'Reminder settings',
    );
    expect(result['pass'], isTrue);
  });

  testWidgets('select time should return the new time when saved', (
    tester,
  ) async {
    ReminderSettings? saved;
    await open(tester, (value) => saved = value);
    await tester.enterText(find.byType(TextFormField), '09:15');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved!.hour, 9);
    expect(saved!.minute, 15);
  });
  testWidgets('save should keep the dialog open when the time is invalid', (
    tester,
  ) async {
    ReminderSettings? saved;
    await open(tester, (value) => saved = value);
    await tester.enterText(find.byType(TextFormField), '25:00');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved, isNull);
    expect(find.text('Enter a time from 00:00 to 23:59'), findsOneWidget);
    expect(find.byType(ReminderSettingsDialog), findsOneWidget);
  });
}
