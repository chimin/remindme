import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import '../support/screenshot_comparator.dart';
import 'golden_test_helper.dart';

void main() {
  late Directory directory;
  late File reference;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('golden_helper_');
    reference = File('${directory.path}/example.png');
  });

  tearDown(() {
    expect(
      directory.absolute.path,
      startsWith(Directory.systemTemp.absolute.path),
    );
    directory.deleteSync(recursive: true);
  });

  testWidgets(
    'capture should save the actual image beside the reference when the difference exceeds the threshold',
    (tester) async {
      final expected = img.encodePng(img.Image(width: 1, height: 1));
      reference.writeAsBytesSync(expected);
      await tester.pumpWidget(const ColoredBox(color: Colors.black));

      final result = await captureAndCompare(
        tester,
        find.byType(ColoredBox),
        reference.path,
        'example',
      );

      expect(result['pass'], isFalse);
      expect(reference.readAsBytesSync(), expected);
      final failed = File('${directory.path}/example_FAILED.png');
      expect(img.decodePng(failed.readAsBytesSync()), isNotNull);
      expect(directory.listSync().length, 2);
    },
  );

  testWidgets(
    'capture should remove the stale failed image when the screenshot matches',
    (tester) async {
      await tester.pumpWidget(const ColoredBox(color: Colors.black));
      await captureAndCompare(
        tester,
        find.byType(ColoredBox),
        reference.path,
        'example',
      );
      final expected = reference.readAsBytesSync();
      failedScreenshotFor(reference).writeAsBytesSync([0]);

      final result = await captureAndCompare(
        tester,
        find.byType(ColoredBox),
        reference.path,
        'example',
      );

      expect(result['pass'], isTrue);
      expect(failedScreenshotFor(reference).existsSync(), isFalse);
      expect(reference.readAsBytesSync(), expected);
    },
  );
}
