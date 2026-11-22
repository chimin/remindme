import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'screenshot_comparator.dart';

void main() {
  late Directory directory;
  late File reference;
  late ScreenshotComparator comparator;
  final golden = Uri.parse('screenshots/example.png');

  Uint8List png(int color, {int width = 2}) => img.encodePng(
    img.fill(
      img.Image(width: width, height: 2, numChannels: 4),
      color: img.ColorRgba8(color, color, color, 255),
    ),
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('screenshot_comparator_');
    reference = File('${directory.path}/screenshots/example.png');
    await reference.parent.create();
    comparator = ScreenshotComparator(
      File('${directory.path}/example_test.dart').uri,
    );
  });

  tearDown(() async {
    expect(
      directory.absolute.path,
      startsWith(Directory.systemTemp.absolute.path),
    );
    await directory.delete(recursive: true);
  });

  test(
    'configuration should install the screenshot comparator when tests start',
    () {
      expect(goldenFileComparator, isA<ScreenshotComparator>());
    },
  );

  test(
    'compare should save the actual image beside the reference when pixels differ',
    () async {
      final expected = png(255);
      final actual = png(0);
      await reference.writeAsBytes(expected);

      await expectLater(
        comparator.compare(actual, golden),
        throwsA(isA<FlutterError>()),
      );

      final failed = File('${reference.parent.path}/example_FAILED.png');
      expect(await failed.readAsBytes(), actual);
      expect(await reference.readAsBytes(), expected);
      expect(await Directory('${directory.path}/failures').exists(), isFalse);
      expect(await reference.parent.list().length, 2);
    },
  );

  test(
    'compare should save the actual image beside the reference when dimensions differ',
    () async {
      final expected = png(255);
      final actual = png(255, width: 3);
      await reference.writeAsBytes(expected);

      await expectLater(
        comparator.compare(actual, golden),
        throwsA(isA<FlutterError>()),
      );

      expect(await failedScreenshotFor(reference).readAsBytes(), actual);
      expect(await reference.readAsBytes(), expected);
    },
  );

  test(
    'compare should save the actual image without creating a reference when the reference is missing',
    () async {
      final actual = png(0);

      await expectLater(
        comparator.compare(actual, golden),
        throwsA(isA<TestFailure>()),
      );

      expect(await failedScreenshotFor(reference).readAsBytes(), actual);
      expect(await reference.exists(), isFalse);
    },
  );

  test(
    'compare should remove the stale failed image when the screenshot matches',
    () async {
      final actual = png(255);
      await reference.writeAsBytes(actual);
      await saveFailedScreenshot(reference, png(0));

      expect(await comparator.compare(actual, golden), isTrue);

      expect(await failedScreenshotFor(reference).exists(), isFalse);
      expect(await reference.readAsBytes(), actual);
    },
  );

  test(
    'update should remove the stale failed image when the reference is replaced',
    () async {
      final actual = png(0);
      await reference.writeAsBytes(png(255));
      await saveFailedScreenshot(reference, actual);

      await comparator.update(golden, actual);

      expect(await reference.readAsBytes(), actual);
      expect(await failedScreenshotFor(reference).exists(), isFalse);
    },
  );
}
