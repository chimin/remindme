import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> theTestShouldCaptureAScreenshotAs(
  WidgetTester tester,
  String path,
) async {
  await tester.runAsync(() async {
    final image = await captureImage(
      find.byType(MaterialApp).evaluate().single,
    );
    try {
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('Unable to encode screenshot: $path');
      }
      final file = File(path);
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
    } finally {
      image.dispose();
    }
  });
}
