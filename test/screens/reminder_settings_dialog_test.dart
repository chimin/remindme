import 'dart:io';

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
      'features/screenshots/reminder_settings_dialog/reminder_settings_dialog_when_displayed.png',
      'Reminder settings',
    );
    expect(result['pass'], isTrue);
  });

  testWidgets('select time should return the new time when saved', (
    tester,
  ) async {
    ReminderSettings? saved;
    await open(tester, (value) => saved = value);
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(find.byType(TimePickerDialog), findsOneWidget);
    expect(
      tester
          .widget<TimePickerDialog>(find.byType(TimePickerDialog))
          .initialTime,
      const TimeOfDay(hour: 8, minute: 0),
    );
    final result = await captureAndCompare(
      tester,
      find.byType(MaterialApp),
      'features/screenshots/reminder_settings_dialog/reminder_settings_dialog_when_time_picker_open.png',
      'Reminder time picker',
    );
    expect(result['pass'], isTrue);
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    final fields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextFormField),
    );
    await tester.enterText(fields.at(0), '21');
    await tester.enterText(fields.at(1), '15');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('21:15'), findsOneWidget);
    await tester.tap(find.byType(TextFormField));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TimePickerDialog>(find.byType(TimePickerDialog))
          .initialTime,
      const TimeOfDay(hour: 21, minute: 15),
    );
    await tester.tap(find.text('Cancel').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(saved!.hour, 21);
    expect(saved!.minute, 15);
  });

  testWidgets(
    'cancel picker should keep the time when selection is cancelled',
    (tester) async {
      ReminderSettings? saved;
      await open(tester, (value) => saved = value);
      expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
      await tester.tap(find.byType(TextFormField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '08:00',
      );
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(saved!.hour, 8);
      expect(saved!.minute, 0);
    },
  );
}
