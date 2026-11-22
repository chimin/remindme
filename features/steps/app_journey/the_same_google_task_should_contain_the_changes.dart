import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:remindme/models/task_metadata.dart';
import 'package:remindme/screens/task_home_screen.dart';

import '../../../patrol_test/support/task_lifecycle.dart';

Future<void> theSameGoogleTaskShouldContainTheChanges(
  PatrolIntegrationTester tester,
) async {
  final context = lifecycleFor(tester);
  final $ = tester;
  await waitFor(
    $,
    () => find.byType(TaskHomeScreen).evaluate().isNotEmpty,
    'Return home after editing task',
  );
  await $(find.text(context.editedTitle)).scrollTo();
  expect(find.text(context.editedTitle), findsOneWidget);
  await pollRemote($, () async {
    final task = await context.api!.tasks.get(context.listId!, context.taskId!);
    return task.title == context.editedTitle &&
            TaskMetadata.parse(task.notes).notes == context.editedNotes
        ? task
        : null;
  }, 'Edited title and notes on the same remote task');
  expect(find.text(context.title), findsNothing);
}
