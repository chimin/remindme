import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../../../patrol_test/support/task_lifecycle.dart';

Future<void> iSaveTheTask(PatrolIntegrationTester tester) async {
  final context = lifecycleFor(tester);
  final $ = tester;
  if (context.taskId == null) context.createAttempted = true;
  await $(find.byTooltip('Save task')).tap();
}
