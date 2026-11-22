import 'package:patrol/patrol.dart';

import '../support/task_lifecycle.dart';

Future<void> iCaptureScreenshotAndCompareWithTheGoldenReference(
  PatrolIntegrationTester tester,
  String checkpoint,
) => lifecycleFor(
  tester,
).iCaptureScreenshotAndCompareWithTheGoldenReference(checkpoint);
