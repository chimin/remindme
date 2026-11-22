import 'package:patrol/patrol.dart';

import '../support/task_lifecycle.dart';

Future<void> theSelectedAccountsTaskListShouldLoad(
  PatrolIntegrationTester tester,
) => lifecycleFor(tester).theSelectedAccountsTaskListShouldLoad();
