import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart' as google;
import 'package:patrol/patrol.dart';
import 'package:provider/provider.dart';
import 'package:remindme/screens/task_home_screen.dart';
import 'package:remindme/services/tasks_repository.dart';

import '../../../patrol_test/support/task_lifecycle.dart';

Future<void> theSelectedAccountsTaskListShouldLoad(
  PatrolIntegrationTester tester,
) async {
  final context = lifecycleFor(tester);
  final $ = tester;
  await waitFor(
    $,
    () => find.byType(TaskHomeScreen).evaluate().isNotEmpty,
    'Home screen after Google authorization',
  );
  expect(context.auth.userEmail?.toLowerCase(), patrolAccount.toLowerCase());
  expect(context.auth.signedIn, isTrue);
  context.repo = Provider.of<TasksRepository>(
    $.tester.element(find.byType(TaskHomeScreen)),
    listen: false,
  );
  await waitFor(
    $,
    () =>
        context.repo.selectedTasklistId != null &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty,
    'Initial task list loading',
  );
  context.listId = context.repo.selectedTasklistId!;
  context.api = google.TasksApi(context.auth.client!);
}
