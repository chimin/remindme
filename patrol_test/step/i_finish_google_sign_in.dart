import 'package:patrol/patrol.dart';

import '../support/task_lifecycle.dart';

Future<void> iFinishGoogleSignIn(PatrolIntegrationTester tester) =>
    lifecycleFor(tester).iFinishGoogleSignIn();
