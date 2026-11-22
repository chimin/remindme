// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

import 'package:flutter_test/flutter_test.dart';

import './step/the_app_is_newly_installed.dart';
import './step/the_user_opens_the_app.dart';
import './step/the_app_should_show_the_login_button.dart';
import './step/the_test_should_capture_a_screenshot_as.dart';

void main() {
  group('''First launch''', () {
    testWidgets(
        '''opening the app should show the login button when newly installed''',
        (tester) async {
      await theAppIsNewlyInstalled(tester);
      await theUserOpensTheApp(tester);
      await theAppShouldShowTheLoginButton(tester, 'Continue with Google');
      await theTestShouldCaptureAScreenshotAs(tester,
          'screenshots/login_screen/login_screen_when_newly_installed.png');
    });
  });
}
