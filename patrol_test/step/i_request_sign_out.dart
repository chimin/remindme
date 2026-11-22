import 'package:patrol/patrol.dart';

import '../support/task_lifecycle.dart';

Future<void> iRequestSignOut(PatrolIntegrationTester tester) =>
    lifecycleFor(tester).iRequestSignOut();
