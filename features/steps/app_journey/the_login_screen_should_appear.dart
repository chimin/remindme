import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';
import 'package:remindme/screens/login_screen.dart';

import '../../../patrol_test/support/task_lifecycle.dart';

Future<void> theLoginScreenShouldAppear(PatrolIntegrationTester tester) async {
  final context = lifecycleFor(tester);
  final $ = tester;
  await waitFor(
    $,
    () =>
        find.byType(LoginScreen).evaluate().isNotEmpty &&
        !context.auth.signedIn &&
        !context.repo.signingIn,
    'Sign in screen after signing out',
  );
  expect(context.repo.selectedTasklistId, isNull);
  expect(context.auth.hasLinkedAccount, isFalse);
}
