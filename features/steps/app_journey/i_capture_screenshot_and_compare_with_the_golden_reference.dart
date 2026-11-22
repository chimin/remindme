import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../../../patrol_test/support/task_lifecycle.dart';

Future<void> iCaptureScreenshotAndCompareWithTheGoldenReference(
  PatrolIntegrationTester tester,
  String checkpoint,
) async {
  final context = lifecycleFor(tester);
  final $ = tester;
  if (!RegExp(r'^\d{2}_[a-z0-9_]+$').hasMatch(checkpoint)) {
    throw ArgumentError('Invalid screenshot checkpoint.');
  }
  final googleScreen =
      checkpoint.startsWith('02_') ||
      checkpoint.startsWith('03_') ||
      checkpoint.startsWith('04_') ||
      checkpoint.startsWith('05_');
  if (googleScreen && context.googleCheckpoint != checkpoint) {
    expect(
      checkpoint == '04_tasks_consent' || checkpoint == '05_tasks_confirmation',
      isFalse,
      reason: freshConsentRequired,
    );
    $.log('Optional Google screen was not shown: $checkpoint');
    return;
  }
  await captureScreenshot(
    $,
    checkpoint,
    settle: !googleScreen && checkpoint != '15_sign_in_required',
  );
  // Keep each message below Android's log length limit.
  $.log(
    'PATROL_SCREENSHOT_CAPTURE ${jsonEncode({'runId': patrolRunId, ...capturedScreenshots[checkpoint]!})}',
  );
  $.log(
    'PATROL_SCREENSHOT_SET ${jsonEncode({'runId': patrolRunId, 'screenshotCount': capturedScreenshots.length})}',
  );
}
