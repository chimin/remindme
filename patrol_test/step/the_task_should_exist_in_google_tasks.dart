import 'package:patrol/patrol.dart';

import '../support/task_lifecycle.dart';

Future<void> theTaskShouldExistInGoogleTasks(PatrolIntegrationTester tester) =>
    lifecycleFor(tester).theTaskShouldExistInGoogleTasks();
