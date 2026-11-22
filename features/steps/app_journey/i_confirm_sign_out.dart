import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/patrol.dart';

import '../../../patrol_test/support/task_lifecycle.dart';

Future<void> iConfirmSignOut(PatrolIntegrationTester tester) async {
  final $ = tester;
  await $.tester.tap(find.widgetWithText(TextButton, 'Sign out'));
  await $.platform.android.waitUntilVisible(
    const AndroidSelector(
      applicationPackage: 'android',
      text: 'Choose an account',
    ),
    timeout: googleTimeout,
  );
}
