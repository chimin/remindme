import 'package:flutter_test/flutter_test.dart';
import 'package:google_account_android/google_account_android.dart';
import 'package:patrol/patrol.dart';
import 'package:remindme/main.dart' as app;
import 'package:remindme/screens/login_screen.dart';

import '../../../patrol_test/support/task_lifecycle.dart';

Future<void> theAppStartsWithCleanLocalData(
  PatrolIntegrationTester tester,
) async {
  final context = lifecycleFor(tester);
  final $ = tester;
  final reset = await GoogleAccountAndroid.channel
      .invokeMethod<bool>('revokeAccessForPatrol', {'email': patrolAccount})
      .timeout(googleTimeout);
  expect(reset, isNotNull, reason: 'Native authorization reset must respond.');
  $.log(
    reset!
        ? 'Native Google Tasks authorization reset completed.'
        : 'No token to revoke; continuing to mandatory fresh Tasks consent.',
  );
  await app.startApp(authRepository: context.auth);
  await waitFor(
    $,
    () => find.byType(LoginScreen).evaluate().isNotEmpty,
    'Clean startup must show the login screen',
  );
  expect(context.auth.signedIn, isFalse);
}
