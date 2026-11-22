import 'package:patrol/patrol.dart';

import '../support/task_lifecycle.dart';

Future<void> iSaveTheTask(PatrolIntegrationTester tester) =>
    lifecycleFor(tester).iSaveTheTask();
