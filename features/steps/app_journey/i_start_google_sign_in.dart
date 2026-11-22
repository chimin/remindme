import 'dart:async';
import 'package:patrol/patrol.dart';

import '../../../patrol_test/support/task_lifecycle.dart';

Future<void> iStartGoogleSignIn(PatrolIntegrationTester tester) async {
  final context = lifecycleFor(tester);
  final $ = tester;
  // Do not wait for Flutter frames while Google owns the foreground.
  await Future<void>.delayed(const Duration(milliseconds: 100));
  context.googleScreens = StreamIterator(completeSignIn($, context.auth));
  await context.advanceGoogleSignIn();
}
