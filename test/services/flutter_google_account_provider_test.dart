import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:remindme/services/flutter_google_account_provider.dart';
import 'package:remindme/services/google_account_provider.dart';
import '../support/fake_google_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGooglePlatform platform;
  late FlutterGoogleAccountProvider provider;
  setUp(() {
    platform = FakeGooglePlatform();
    GoogleSignInPlatform.instance = platform;
    provider = FlutterGoogleAccountProvider(
      clientId: 'test.apps.googleusercontent.com',
    );
  });
  tearDown(() async {
    provider.dispose();
    unawaited(platform.events.close());
  });
  test(
    'link should authorize tasks when the user selects an account',
    () async {
      final result = await provider.link();
      expect(result.account.email, 'test@example.com');
      expect(result.accessToken, 'token');
      expect(platform.manualAttempts, 1);
      expect(platform.signOutCalls, 0);
    },
  );
  test(
    'authorize should restore the remembered identity when access is requested silently',
    () async {
      platform.restoreUser = true;
      expect(
        await provider.authorize(const LinkedGoogleAccount('test@example.com')),
        'token',
      );
      expect(platform.silentAttempts, 1);
      expect(platform.manualAttempts, 0);
    },
  );
  test(
    'authorize should require explicit reconnection when restoration returns no account',
    () async {
      await expectLater(
        provider.authorize(const LinkedGoogleAccount('test@example.com')),
        throwsA(
          isA<AccountException>().having(
            (e) => e.reason,
            'reason',
            AccountFailure.interactionRequired,
          ),
        ),
      );
      expect(platform.manualAttempts, 0);
      expect(platform.signOutCalls, 0);
    },
  );
  test(
    'authorize should reject a different identity when restoring the remembered account',
    () async {
      platform.restoreUser = true;
      await expectLater(
        provider.authorize(const LinkedGoogleAccount('other@example.com')),
        throwsA(
          isA<AccountException>().having(
            (e) => e.reason,
            'reason',
            AccountFailure.mismatch,
          ),
        ),
      );
    },
  );
  test(
    'authorize should avoid consent UI when scopes need interactive approval',
    () async {
      platform.restoreUser = true;
      platform.requireConsent = true;
      await expectLater(
        provider.authorize(const LinkedGoogleAccount('test@example.com')),
        throwsA(
          isA<AccountException>().having(
            (e) => e.reason,
            'reason',
            AccountFailure.interactionRequired,
          ),
        ),
      );
      expect(platform.manualAttempts, 0);
    },
  );
  test(
    'forget should retain Google permissions when the local connection is removed',
    () async {
      await provider.link();
      await provider.forget();
      expect(platform.signOutCalls, 1);
      expect(platform.disconnectCalls, 0);
    },
  );
  test(
    'initialize should report configuration failure when the iOS client ID is missing',
    () async {
      provider.dispose();
      provider = FlutterGoogleAccountProvider(clientId: '');
      await expectLater(
        provider.initialize(),
        throwsA(
          isA<AccountException>().having(
            (e) => e.reason,
            'reason',
            AccountFailure.configuration,
          ),
        ),
      );
    },
  );
}
