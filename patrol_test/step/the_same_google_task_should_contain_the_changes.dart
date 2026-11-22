import 'package:patrol/patrol.dart';

import '../support/task_lifecycle.dart';

Future<void> theSameGoogleTaskShouldContainTheChanges(
  PatrolIntegrationTester tester,
) => lifecycleFor(tester).theSameGoogleTaskShouldContainTheChanges();
