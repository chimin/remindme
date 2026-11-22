import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../../../patrol_test/support/task_lifecycle.dart';

Future<void> iFinishGoogleSignIn(PatrolIntegrationTester tester) async {
  final context = lifecycleFor(tester);
  await context.advanceGoogleSignIn();
  expect(
    context.googleCheckpoint,
    isNull,
    reason: 'All Google checkpoints must be captured.',
  );
}
