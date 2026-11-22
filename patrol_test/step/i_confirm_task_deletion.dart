import 'package:patrol/patrol.dart';

import '../support/task_lifecycle.dart';

Future<void> iConfirmTaskDeletion(PatrolIntegrationTester tester) =>
    lifecycleFor(tester).iConfirmTaskDeletion();
