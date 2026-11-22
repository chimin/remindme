// ignore_for_file: invalid_use_of_visible_for_testing_member

import '../scenario_runner.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:remindme/services/reminder_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

ScenarioCases defineScenarios() {
  final scenarios = <String, ScenarioFactory>{};

  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  void prepareScenario() {
    SharedPreferences.setMockInitialValues({});
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ReminderService.channel, (call) async {
          calls.add(call);
          return null;
        });
  }

  scenarios['0'] = (state) async {
    prepareScenario();
    state.next = () async {
      final settings = await ReminderSettings.load();
      state.next = () async {
        expect(settings.enabled, isTrue);
        expect(settings.hour, 8);
        expect(settings.minute, 0);
      };
    };
  };

  scenarios['1'] = (state) async {
    prepareScenario();
    state.next = () async {
      await const ReminderSettings(enabled: false, hour: 23, minute: 45).save();
      final settings = await ReminderSettings.load();
      state.next = () async {
        expect(settings.enabled, isFalse);
        expect(settings.hour, 23);
        expect(settings.minute, 45);
      };
    };
  };

  scenarios['2'] = (state) async {
    prepareScenario();
    state.next = () async {
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
      state.next = () async {
        expect(calls.map((call) => call.arguments['active']), [true, false]);
        expect(calls.last.arguments['tasks'], isEmpty);
      };
    };
  };

  scenarios['3'] = (state) async {
    prepareScenario();
    state.next = () async {
      await const ReminderSettings(enabled: false).save();
      await ReminderService().refresh(
        () async => {'active': true, 'tasks': []},
      );
      state.next = () async {
        expect(calls.single.method, 'replace');
        expect(calls.single.arguments['enabled'], isFalse);
      };
    };
  };

  scenarios['4'] = (state) async {
    prepareScenario();
    state.next = () async {
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
      state.next = () async {
        expect(calls.single.arguments['active'], isFalse);
      };
    };
  };
  scenarios['5'] = (state) async {
    prepareScenario();
    state.next = () async {
      await ReminderService().refresh(
        () async => {'active': true, 'tasks': []},
        notifyNow: true,
      );
      state.next = () async {
        expect(calls.single.arguments['notifyNow'], isTrue);
      };
    };
  };

  return scenarios;
}
