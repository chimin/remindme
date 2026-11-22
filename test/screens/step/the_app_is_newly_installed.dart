import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> theAppIsNewlyInstalled(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  addTearDown(() => SharedPreferences.setMockInitialValues({}));
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(360, 640);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);

  final messenger = tester.binding.defaultBinaryMessenger;
  const updates = EventChannel('home_widget/updates');
  const homeWidget = MethodChannel('home_widget');
  messenger.setMockStreamHandler(
    updates,
    MockStreamHandler.inline(onListen: (_, events) {}),
  );
  messenger.setMockMethodCallHandler(homeWidget, (_) async => null);
  addTearDown(() {
    messenger.setMockStreamHandler(updates, null);
    messenger.setMockMethodCallHandler(homeWidget, null);
  });

  await tester.runAsync(() async {
    for (final entry in {
      'Roboto': 'test/fonts/roboto-regular.ttf',
      'MaterialIcons': 'test/fonts/materialicons-regular.otf',
    }.entries) {
      final bytes = await File(entry.value).readAsBytes();
      await (FontLoader(
        entry.key,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
}
