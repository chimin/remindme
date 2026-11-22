import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pixelmatch/pixelmatch.dart' as pm;

const _marker = 'PATROL_SCREENSHOT_SET ';

Future<String> comparePatrolScreenshot(
  Directory screenshots,
  File deviceLog,
  String runId, {
  bool updateGoldens = false,
  double allowedDifferencePercent = 5,
}) async {
  Map<String, dynamic>? request;
  final captures = <Map<String, dynamic>>[];
  for (final line in const LineSplitter().convert(
    await deviceLog.readAsString(),
  )) {
    final start = line.indexOf('PATROL_LOG ');
    if (start < 0) continue;
    Map<String, dynamic> event;
    try {
      event =
          jsonDecode(line.substring(start + 'PATROL_LOG '.length))
              as Map<String, dynamic>;
    } on FormatException {
      continue;
    }
    final message = event['message'];
    if (message is! String) continue;
    const captureMarker = 'PATROL_SCREENSHOT_CAPTURE ';
    final isCapture = message.startsWith(captureMarker);
    if (!isCapture && !message.startsWith(_marker)) continue;
    final candidate =
        jsonDecode(
              message.substring(
                isCapture ? captureMarker.length : _marker.length,
              ),
            )
            as Map<String, dynamic>;
    if (candidate['runId'] != runId) continue;
    if (isCapture) {
      captures.add(candidate);
    } else {
      request = candidate;
    }
  }
  if (request == null) {
    throw StateError('No screenshot set requested for run $runId.');
  }
  if (!allowedDifferencePercent.isFinite ||
      allowedDifferencePercent < 0 ||
      allowedDifferencePercent > 100) {
    throw ArgumentError.value(
      allowedDifferencePercent,
      'allowedDifferencePercent',
    );
  }
  if (captures.length != request['screenshotCount']) {
    throw StateError(
      'Incomplete screenshot metadata: expected ${request['screenshotCount']}, '
      'received ${captures.length}.',
    );
  }
  if (captures.isEmpty) throw StateError('The screenshot set is empty.');
  final results = <Map<String, Object?>>[];
  final failures = <String>[];
  final seen = <String>{};
  for (final capture in captures) {
    final checkpoint = capture['checkpoint'] as String;
    if (!RegExp(r'^\d{2}_[a-z0-9_]+$').hasMatch(checkpoint) ||
        checkpoint == '99_failure' ||
        !seen.add(checkpoint)) {
      throw FormatException(
        'Invalid or duplicate screenshot checkpoint: $checkpoint',
      );
    }
    final actualFile = File(
      '${deviceLog.parent.path}/screenshots/$checkpoint.png',
    );
    final baseline = File('${screenshots.path}/$checkpoint.png');
    final failed = File('${screenshots.path}/${checkpoint}_FAILED.png');
    final result = <String, Object?>{'checkpoint': checkpoint};
    results.add(result);
    try {
      if (await failed.exists()) await failed.delete();
      final actualBytes = await actualFile.readAsBytes();
      final actual = img.decodePng(actualBytes);
      if (actual == null) {
        throw StateError('Invalid screenshot: ${actualFile.path}');
      }
      final content = _appContent(actual, capture);
      if (updateGoldens) {
        await baseline.parent.create(recursive: true);
        await baseline.writeAsBytes(actualBytes, flush: true);
        result['status'] = 'created_for_review';
        continue;
      }
      if (!await baseline.exists()) {
        throw StateError(
          'Missing golden reference: ${baseline.path}. '
          'Use --update-goldens explicitly to create references for review.',
        );
      }
      final expected = img.decodePng(await baseline.readAsBytes());
      if (expected == null) {
        throw StateError('Invalid golden: ${baseline.path}');
      }
      if (actual.width != expected.width || actual.height != expected.height) {
        throw StateError(
          'Screenshot dimensions differ for $checkpoint: '
          'actual ${actual.width}x${actual.height}, '
          'golden ${expected.width}x${expected.height}.',
        );
      }
      final reference = _appContent(expected, capture);
      final pixels = content.width * content.height;
      final changed = pm.pixelmatch(
        Uint8List.fromList(reference.getBytes(order: img.ChannelOrder.rgba)),
        Uint8List.fromList(content.getBytes(order: img.ChannelOrder.rgba)),
        null,
        content.width,
        content.height,
        {'threshold': 0.1, 'includeAA': true},
      );
      final percent = changed * 100 / pixels;
      final passed = percent <= allowedDifferencePercent;
      result.addAll({
        'differentPixels': changed,
        'comparedPixels': pixels,
        'differencePercent': percent,
        'status': passed ? 'passed' : 'failed',
      });
      if (!passed) {
        await actualFile.copy(failed.path);
        result['failedScreenshot'] = failed.path;
        failures.add(
          '$checkpoint: ${percent.toStringAsFixed(4)}% exceeds '
          '$allowedDifferencePercent%.',
        );
      }
    } on FileSystemException catch (error) {
      if (await actualFile.exists()) {
        await actualFile.copy(failed.path);
        result['failedScreenshot'] = failed.path;
      }
      result.addAll({'status': 'failed', 'error': error.toString()});
      failures.add('$checkpoint: $error');
    } on StateError catch (error) {
      if (await actualFile.exists()) {
        await actualFile.copy(failed.path);
        result['failedScreenshot'] = failed.path;
      }
      result.addAll({'status': 'failed', 'error': error.message});
      failures.add('$checkpoint: ${error.message}');
    }
  }
  final report = File('${deviceLog.parent.path}/screenshot_comparison.json');
  await report.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'runId': runId,
      'library': 'pixelmatch',
      'pixelColorThreshold': 0.1,
      'includeAntiAliasedPixels': true,
      'allowedDifferencePercent': allowedDifferencePercent,
      'mode': updateGoldens ? 'create_for_review' : 'compare',
      'screenshots': results,
    }),
    flush: true,
  );
  if (failures.isNotEmpty) {
    throw StateError(
      'Screenshot set comparison failed:\n${failures.join('\n')}'
      '\nReport: ${report.path}. Golden references were not changed.',
    );
  }
  if (updateGoldens) {
    return 'Created ${results.length} golden references for review. '
        'No baseline comparison was asserted. Report: ${report.path}';
  }
  final summary = results
      .map(
        (result) =>
            '${result['checkpoint']}: '
            '${(result['differencePercent'] as double).toStringAsFixed(4)}%',
      )
      .join('\n');
  return 'Compared ${results.length} screenshots against golden references '
      '(limit $allowedDifferencePercent% per screenshot):\n$summary'
      '\nReport: ${report.path}';
}

img.Image _appContent(img.Image image, Map<String, dynamic> capture) {
  final left = capture['left'] as int;
  final top = capture['top'] as int;
  final right = capture['right'] as int;
  final bottom = capture['bottom'] as int;
  if ([left, top, right, bottom].any((value) => value < 0) ||
      left + right >= image.width ||
      top + bottom >= image.height) {
    throw StateError('Invalid system-bar insets for ${capture['checkpoint']}.');
  }
  // Apply identical system-bar crops to actual and golden native screenshots.
  return img
      .copyCrop(
        image,
        x: left,
        y: top,
        width: image.width - left - right,
        height: image.height - top - bottom,
      )
      .convert(numChannels: 4);
}
