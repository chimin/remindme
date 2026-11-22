import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:remindme/models/task_metadata.dart';
import 'package:remindme/screens/task_home_screen.dart';

import '../../../patrol_test/support/task_lifecycle.dart';

Future<void> theTaskShouldExistInGoogleTasks(
  PatrolIntegrationTester tester,
) async {
  final context = lifecycleFor(tester);
  final $ = tester;
  await waitFor(
    $,
    () => find.byType(TaskHomeScreen).evaluate().isNotEmpty,
    'Return home after creating task',
  );
  await $(find.text(context.title)).scrollTo();
  expect(find.text(context.title), findsOneWidget);
  final created = await pollRemote($, () async {
    final tasks = await remoteTasks(context.api!, context.listId!);
    final matches = tasks.where((task) => task.title == context.title).toList();
    if (matches.length != 1 ||
        TaskMetadata.parse(matches.single.notes).notes != context.notes) {
      return null;
    }
    return matches.single;
  }, 'Created task must exist in Google Tasks');
  context.taskId = created.id!;
}
