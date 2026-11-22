import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../../../patrol_test/support/task_lifecycle.dart';

Future<void> iEnterATaskTitleAndNotes(PatrolIntegrationTester tester) async {
  final context = lifecycleFor(tester);
  final $ = tester;
  await $(find.byTooltip('Add task')).tap();
  await $(#task_title).enterText(context.title);
  await $(#task_notes).enterText(context.notes);
  await expectEditor($, title: context.title, notes: context.notes);
}
