import 'package:patrol/patrol.dart';

import '../support/task_lifecycle.dart';

Future<void> iEnterATaskTitleAndNotes(PatrolIntegrationTester tester) =>
    lifecycleFor(tester).iEnterATaskTitleAndNotes();
