import 'package:patrol/patrol.dart';

import '../support/task_lifecycle.dart';

Future<void> theTaskShouldBeAbsentFromGoogleTasks(
  PatrolIntegrationTester tester,
) => lifecycleFor(tester).theTaskShouldBeAbsentFromGoogleTasks();
