import 'package:patrol/patrol.dart';

import '../support/task_lifecycle.dart';

Future<void> iEditTheTasksTitleAndNotes(PatrolIntegrationTester tester) =>
    lifecycleFor(tester).iEditTheTasksTitleAndNotes();
