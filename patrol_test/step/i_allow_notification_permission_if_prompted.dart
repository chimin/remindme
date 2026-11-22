import 'package:patrol/patrol.dart';

import '../support/task_lifecycle.dart';

Future<void> iAllowNotificationPermissionIfPrompted(
  PatrolIntegrationTester tester,
) => lifecycleFor(tester).iAllowNotificationPermissionIfPrompted();
