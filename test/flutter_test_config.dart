import 'dart:async';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // 360 x 640 logical pixels, matching the project's golden screenshots.
    final view = binding.platformDispatcher.implicitView!;
    view.devicePixelRatio = 2.0;
    view.physicalSize = const Size(720, 1280);
    addTearDown(view.resetDevicePixelRatio);
    addTearDown(view.resetPhysicalSize);
  });

  await testMain();
}
