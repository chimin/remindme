import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../../../patrol_test/support/task_lifecycle.dart';

Future<void> iEditTheTasksTitleAndNotes(PatrolIntegrationTester tester) async {
  final context = lifecycleFor(tester);
  final $ = tester;
  await $(find.text(context.title)).scrollTo().tap();
  await expectEditor($, title: context.title, notes: context.notes);
  await $(#task_title).enterText(context.editedTitle);
  await $(#task_notes).enterText(context.editedNotes);
  await expectEditor($, title: context.editedTitle, notes: context.editedNotes);
}
