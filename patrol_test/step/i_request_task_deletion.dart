import 'package:patrol/patrol.dart';

import '../support/task_lifecycle.dart';

Future<void> iRequestTaskDeletion(PatrolIntegrationTester tester) =>
    lifecycleFor(tester).iRequestTaskDeletion();
