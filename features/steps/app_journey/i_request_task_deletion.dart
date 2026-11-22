import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../../../patrol_test/support/task_lifecycle.dart';

Future<void> iRequestTaskDeletion(PatrolIntegrationTester tester) async {
  final $ = tester;
  await $(find.byTooltip('Delete task')).tap();
  await waitFor(
    $,
    () => find.text('Delete task?').evaluate().isNotEmpty,
    'Task deletion confirmation',
  );
}
