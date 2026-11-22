import 'package:patrol/patrol.dart';

import '../../../patrol_test/support/task_lifecycle.dart';

Future<void> iContinueGoogleSignInToIfShown(
  PatrolIntegrationTester tester,
  String checkpoint,
) async {
  final context = lifecycleFor(tester);
  const checkpoints = [
    '02_account_selected',
    '02_development_warning',
    '03_development_confirmation',
    '04_tasks_consent',
    '05_tasks_confirmation',
  ];
  final target = checkpoints.indexOf(checkpoint);
  if (target < 0) {
    throw ArgumentError('Unknown Google checkpoint: $checkpoint');
  }
  while (context.googleCheckpoint != null &&
      checkpoints.indexOf(context.googleCheckpoint!) < target) {
    await context.advanceGoogleSignIn();
  }
}
