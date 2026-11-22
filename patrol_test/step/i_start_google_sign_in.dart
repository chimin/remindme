import 'package:patrol/patrol.dart';

import '../support/task_lifecycle.dart';

Future<void> iStartGoogleSignIn(PatrolIntegrationTester tester) =>
    lifecycleFor(tester).iStartGoogleSignIn();
