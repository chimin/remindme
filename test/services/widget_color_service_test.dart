import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:remindme/models/widget_color_config.dart';
import 'package:remindme/services/widget_color_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      MethodChannel('home_widget'),
      (call) async {
        calls.add(call);
        if (call.method == 'getWidgetData') {
          final args = (call.arguments as Map).cast<String, dynamic>();
          return args['id'] == WidgetColorService.configKey
              ? jsonEncode({
                  'textColor': 0xFF102030,
                  'backgroundColor': 0xFF445566,
                  'backgroundAlpha': 0x77,
                  'overdueColor': 0xFF778899,
                })
              : null;
        }
        return true;
      },
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(MethodChannel('home_widget'), null);
  });

  test('loadConfig should return defaults when nothing saved', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      MethodChannel('home_widget'),
      (call) async => null,
    );

    final config = await WidgetColorService.loadConfig();

    expect(config.textColor, 0xFF000000);
    expect(config.backgroundColor, 0xFFFFFFFF);
    expect(config.backgroundAlpha, 0x80);
    expect(config.overdueColor, 0xFFF44336);
  });

  test('loadConfig should return saved config', () async {
    final config = await WidgetColorService.loadConfig();

    expect(config.textColor, 0xFF102030);
    expect(config.backgroundColor, 0xFF445566);
    expect(config.backgroundAlpha, 0x77);
    expect(config.overdueColor, 0xFF778899);
  });

  test('saveConfig should write task_widget_config JSON', () async {
    const config = WidgetColorConfig(
      textColor: 0xFF111111,
      overdueColor: 0xFF222222,
    );

    await WidgetColorService.saveConfig(config);

    final call = calls.firstWhere((c) => c.method == 'saveWidgetData');
    final args = (call.arguments as Map).cast<String, dynamic>();
    expect(args['id'], WidgetColorService.configKey);
    final data = jsonDecode(args['data'] as String) as Map<String, dynamic>;
    expect(data['textColor'], 0xFF111111);
    expect(data['overdueColor'], 0xFF222222);
  });
}
