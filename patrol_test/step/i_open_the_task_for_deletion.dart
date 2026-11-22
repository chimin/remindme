import 'package:patrol/patrol.dart';

import '../support/task_lifecycle.dart';

Future<void> iOpenTheTaskForDeletion(PatrolIntegrationTester tester) =>
    lifecycleFor(tester).iOpenTheTaskForDeletion();
