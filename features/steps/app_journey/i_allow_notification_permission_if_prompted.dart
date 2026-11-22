import 'package:patrol/patrol.dart';

import '../../../patrol_test/support/task_lifecycle.dart';

Future<void> iAllowNotificationPermissionIfPrompted(
  PatrolIntegrationTester tester,
) async {
  final context = lifecycleFor(tester);
  final $ = tester;
  final android = $.platform.android;
  final clock = Stopwatch()..start();
  while (clock.elapsed < remoteTimeout) {
    final views = flattenNativeViews(
      (await android.getNativeViews(null)).roots,
    ).toList();
    final permissionViews = views.where(
      (view) =>
          view.applicationPackage?.endsWith('.permissioncontroller') ?? false,
    );
    final notificationPrompt = permissionViews.any(
      (view) => nativeLabel(view).contains('send you notifications'),
    );
    if (notificationPrompt) {
      final allow = permissionViews.where(
        (view) =>
            view.isEnabled &&
            (view.resourceName?.endsWith('/permission_allow_button') ?? false),
      );
      if (allow.isNotEmpty) {
        await tapNativeView($, allow.first);
        await waitFor(
          $,
          () => !context.auth.signingIn,
          'Google sign-in completion',
        );
        return;
      }
    }
    // Keep polling native UI while a system dialog may pause Flutter.
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
}
