import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../../../patrol_test/support/task_lifecycle.dart';

Future<void> iOpenTheTaskForDeletion(PatrolIntegrationTester tester) async {
  final context = lifecycleFor(tester);
  final $ = tester;
  await $(find.text(context.editedTitle)).scrollTo().tap();
  await expectEditor($, title: context.editedTitle, notes: context.editedNotes);
}
