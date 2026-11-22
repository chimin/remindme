import 'package:patrol/patrol.dart';

import '../support/task_lifecycle.dart';

Future<void> iContinueGoogleSignInToIfShown(
  PatrolIntegrationTester tester,
  String checkpoint,
) => lifecycleFor(tester).iContinueGoogleSignInToIfShown(checkpoint);
