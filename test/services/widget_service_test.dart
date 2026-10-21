import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart';

import 'package:remindme/services/widget_service.dart';

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
        return true;
      },
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(MethodChannel('home_widget'), null);
  });

  List<dynamic> savedWidgetData() {
    final call = calls.firstWhere((c) => c.method == 'saveWidgetData');
    final args = (call.arguments as Map).cast<String, dynamic>();
    return jsonDecode(args['data'] as String) as List<dynamic>;
  }

  test('updateWidget should save task list name when name is given', () async {
    await WidgetService.updateWidget(
      [Task(id: '1', title: 'Task')],
      taskListName: 'Work',
    );

    final items = savedWidgetData();
    expect(items, isNotEmpty);
    expect((items.first as Map)['type'], 'tasklist');
    expect((items.first as Map)['title'], 'Work');
  });

  test('updateWidget should save widget data without task list name '
      'when name is not given', () async {
    await WidgetService.updateWidget([Task(id: '1', title: 'Task')]);

    final items = savedWidgetData();
    expect(
      items.map((e) => (e as Map)['type']),
      isNot(contains('tasklist')),
    );
  });

  test('updateWidget should request widget refresh when data is saved',
      () async {
    await WidgetService.updateWidget(
      [Task(id: '1', title: 'Task')],
      taskListName: 'Work',
    );

    final update = calls.firstWhere((c) => c.method == 'updateWidget');
    final args = (update.arguments as Map).cast<String, dynamic>();
    expect(args['android'], 'TaskWidgetProvider');
  });

  test('clearWidget should clear widget data when called', () async {
    await WidgetService.clearWidget();

    final call = calls.firstWhere((c) => c.method == 'saveWidgetData');
    final args = (call.arguments as Map).cast<String, dynamic>();
    expect(args['id'], WidgetService.dataKey);
    expect(args['data'], isNull);
  });

  test('updateWidget should exclude completed tasks when saving widget data',
      () async {
    final now = DateTime.now();
    await WidgetService.updateWidget([
      Task(id: '1', title: 'Open task', due: now.toIso8601String()),
      Task(
        id: '2',
        title: 'Done task',
        status: 'completed',
        due: now.toIso8601String(),
      ),
    ]);

    final items = savedWidgetData();
    final titles = items
        .whereType<Map>()
        .where((e) => e['type'] == 'task')
        .map((e) => e['title'])
        .toList();
    expect(titles, ['Open task']);
  });
}
