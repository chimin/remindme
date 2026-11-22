import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

File failedScreenshotFor(File reference) {
  final name = reference.uri.pathSegments.last;
  final extension = name.lastIndexOf('.');
  final failedName = extension < 0
      ? '${name}_FAILED'
      : '${name.substring(0, extension)}_FAILED${name.substring(extension)}';
  return File.fromUri(reference.uri.resolveUri(Uri(path: failedName)));
}

Future<void> saveFailedScreenshot(File reference, List<int> bytes) async {
  final failed = failedScreenshotFor(reference);
  await failed.parent.create(recursive: true);
  await failed.writeAsBytes(bytes, flush: true);
}

Future<void> clearFailedScreenshot(File reference) async {
  final failed = failedScreenshotFor(reference);
  if (await failed.exists()) await failed.delete();
}

class ScreenshotComparator extends LocalFileComparator {
  ScreenshotComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final reference = File.fromUri(basedir.resolveUri(golden));
    ComparisonResult? result;
    try {
      result = await GoldenFileComparator.compareLists(
        imageBytes,
        await getGoldenBytes(golden),
      );
      if (result.passed) {
        await clearFailedScreenshot(reference);
        return true;
      }
      throw FlutterError(
        'Golden "$golden": ${result.error}\n'
        'Failed screenshot: ${failedScreenshotFor(reference).path}',
      );
    } catch (_) {
      await saveFailedScreenshot(reference, imageBytes);
      rethrow;
    } finally {
      result?.dispose();
    }
  }

  @override
  Future<void> update(Uri golden, Uint8List imageBytes) async {
    await super.update(golden, imageBytes);
    await clearFailedScreenshot(File.fromUri(basedir.resolveUri(golden)));
  }
}
