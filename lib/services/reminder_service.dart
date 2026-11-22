import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/log.dart';

class ReminderSettings {
  const ReminderSettings({this.enabled = true, this.hour = 8, this.minute = 0});

  final bool enabled;
  final int hour;
  final int minute;

  static Future<ReminderSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    return ReminderSettings(
      enabled: prefs.getBool('reminder_enabled') ?? true,
      hour: (prefs.getInt('reminder_hour') ?? 8).clamp(0, 23),
      minute: (prefs.getInt('reminder_minute') ?? 0).clamp(0, 59),
    );
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('reminder_enabled', enabled);
    await prefs.setInt('reminder_hour', hour);
    await prefs.setInt('reminder_minute', minute);
  }
}

class ReminderService {
  static const channel = MethodChannel('chimin.remindme/reminders');
  Future<void> _work = Future.value();

  // Read state inside the queue so cancellation cannot be undone by stale work.
  Future<void> refresh(
    Future<Map<String, Object?>> Function() readState, {
    bool notifyNow = false,
  }) {
    final result = _work.then((_) async {
      final settings = await ReminderSettings.load();
      final state = await readState();
      await channel.invokeMethod<void>('replace', {
        ...state,
        'notifyNow': notifyNow,
        'enabled': settings.enabled,
        'hour': settings.hour,
        'minute': settings.minute,
      });
    });
    _work = result.catchError((Object error, StackTrace stack) {
      if (error is! MissingPluginException) {
        logError('Unable to update daily reminders', error, stack);
      }
    });
    return _work;
  }

  static Future<void> requestPermission() async {
    try {
      await channel.invokeMethod<void>('requestPermission');
    } on MissingPluginException {
      // Desktop and widget tests have no mobile notification implementation.
    } catch (error, stack) {
      logError('Unable to request reminder permission', error, stack);
    }
  }

  static Future<void> openChannelSettings() =>
      channel.invokeMethod<void>('openChannelSettings');
}
