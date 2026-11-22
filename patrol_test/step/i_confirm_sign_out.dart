import 'package:patrol/patrol.dart';

import '../support/task_lifecycle.dart';

Future<void> iConfirmSignOut(PatrolIntegrationTester tester) =>
    lifecycleFor(tester).iConfirmSignOut();
