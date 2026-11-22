import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:remindme/screens/task_home_screen.dart';

import '../../../patrol_test/support/task_lifecycle.dart';

Future<void> theTaskShouldBeAbsentFromGoogleTasks(
  PatrolIntegrationTester tester,
) async {
  final context = lifecycleFor(tester);
  final $ = tester;
  await waitFor(
    $,
    () =>
        find.byType(TaskHomeScreen).evaluate().isNotEmpty &&
        find.text(context.editedTitle).evaluate().isEmpty,
    'Deleted task absent from home screen',
  );
  await pollRemote($, () async {
    final tasks = await remoteTasks(context.api!, context.listId!);
    return tasks.any((task) => task.id == context.taskId) ? null : true;
  }, 'Deleted task absent from Google Tasks');
  context.deleted = true;
  expect(find.text(context.title), findsNothing);
}
