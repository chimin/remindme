import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remindme/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ReminderService.channel, (call) async {
          calls.add(call);
          return null;
        });
  });

  test(
    'load should enable reminders at eight when settings are absent',
    () async {
      final settings = await ReminderSettings.load();
      expect(settings.enabled, isTrue);
      expect(settings.hour, 8);
      expect(settings.minute, 0);
    },
  );

  test(
    'save should restore enabled state and time when settings reload',
    () async {
      await const ReminderSettings(enabled: false, hour: 23, minute: 45).save();
      final settings = await ReminderSettings.load();
      expect(settings.enabled, isFalse);
      expect(settings.hour, 23);
      expect(settings.minute, 45);
    },
  );

  test(
    'refresh should leave cancellation last when previous work is delayed',
    () async {
      final service = ReminderService();
      final pending = Completer<Map<String, Object?>>();
      final refresh = service.refresh(() => pending.future);
      final cancel = service.refresh(
        () async => {'active': false, 'tasks': []},
      );
      pending.complete({
        'active': true,
        'tasks': [
          {'title': 'Old task'},
        ],
      });
      await Future.wait([refresh, cancel]);
      expect(calls.map((call) => call.arguments['active']), [true, false]);
      expect(calls.last.arguments['tasks'], isEmpty);
    },
  );

  test(
    'refresh should replace with disabled settings when reminders are disabled',
    () async {
      await const ReminderSettings(enabled: false).save();
      await ReminderService().refresh(
        () async => {'active': true, 'tasks': []},
      );
      expect(calls.single.method, 'replace');
      expect(calls.single.arguments['enabled'], isFalse);
    },
  );

  test(
    'refresh should continue processing when the platform denies a request',
    () async {
      var attempts = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(ReminderService.channel, (call) async {
            if (attempts++ == 0) throw PlatformException(code: 'denied');
            calls.add(call);
            return null;
          });
      final service = ReminderService();
      await service.refresh(() async => {'active': true, 'tasks': []});
      await service.refresh(() async => {'active': false, 'tasks': []});
      expect(calls.single.arguments['active'], isFalse);
    },
  );
  test(
    'refresh should request immediate delivery when the app opens',
    () async {
      await ReminderService().refresh(
        () async => {'active': true, 'tasks': []},
        notifyNow: true,
      );
      expect(calls.single.arguments['notifyNow'], isTrue);
    },
  );
}
