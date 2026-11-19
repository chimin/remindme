import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remindme/services/auth_repository.dart';
import 'package:remindme/services/google_account_provider.dart';
import '../support/fake_account_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAccountProvider provider;
  late AuthRepository auth;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    provider = FakeAccountProvider();
    auth = AuthRepository(provider: provider);
  });
  tearDown(() => auth.dispose());
  test(
    'initialize should leave linking to the foreground when no account was saved',
    () async {
      await auth.init();
      expect(auth.hasLinkedAccount, isFalse);
      expect(provider.links, 0);
      expect(provider.initializations, 0);
    },
  );
  test(
    'initialize should preserve cached account access when the device is offline',
    () async {
      SharedPreferences.setMockInitialValues({
        AuthRepository.accountPreference: 'test@example.com',
      });
      provider.tokenError = StateError('offline');
      await auth.init();
      expect(auth.signedIn, isTrue);
      expect(auth.client, isNotNull);
      expect(provider.authorizations, 0);
    },
  );
  test(
    'link should remember the account when authorization succeeds',
    () async {
      await auth.init();
      await auth.signIn();
      expect(auth.userEmail, 'test@example.com');
      expect(
        (await SharedPreferences.getInstance()).getString(
          AuthRepository.accountPreference,
        ),
        'test@example.com',
      );
      expect(provider.forgets, 0);
    },
  );
  test('link should allow retry when account selection is canceled', () async {
    provider.linkError = const AccountException(
      AccountFailure.canceled,
      'Canceled',
    );
    await auth.signIn();
    expect(auth.signedIn, isFalse);
    expect(auth.signingIn, isFalse);
    provider.linkError = null;
    await auth.signIn();
    expect(auth.signedIn, isTrue);
    expect(provider.forgets, 0);
  });
  test('link should share the active attempt when requests overlap', () async {
    provider.pendingLink = Completer();
    final first = auth.signIn();
    await Future<void>.delayed(Duration.zero);
    await auth.signIn();
    expect(provider.links, 1);
    provider.pendingLink!.complete(
      GoogleAccountAuthorization(provider.account, 'token'),
    );
    await first;
  });
  test(
    'link should preserve the cache owner when a different account is returned',
    () async {
      await auth.signIn();
      provider.account = const LinkedGoogleAccount('other@example.com');
      await auth.requestAuthorization();
      expect(auth.userEmail, 'test@example.com');
      expect(auth.requiresReconnect, isTrue);
    },
  );
  test(
    'link should preserve unowned data when migration verification fails',
    () async {
      auth.validateAccount = (_) async => throw const AccountException(
        AccountFailure.mismatch,
        'Wrong account',
      );
      await auth.signIn();
      expect(auth.hasLinkedAccount, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getString(
          AuthRepository.accountPreference,
        ),
        isNull,
      );
    },
  );
  test(
    'link should ignore late authorization when the user disconnects',
    () async {
      provider.pendingLink = Completer();
      final first = auth.signIn();
      await Future<void>.delayed(Duration.zero);
      await auth.signOut();
      provider.pendingLink!.complete(
        GoogleAccountAuthorization(provider.account, 'token'),
      );
      await first;
      expect(auth.signedIn, isFalse);
      expect(
        (await SharedPreferences.getInstance()).getString(
          AuthRepository.accountPreference,
        ),
        isNull,
      );
    },
  );
  test(
    'token request should share silent authorization when requests overlap',
    () async {
      SharedPreferences.setMockInitialValues({
        AuthRepository.accountPreference: 'test@example.com',
      });
      await auth.init();
      provider.pendingToken = Completer();
      final first = auth.accessToken();
      final second = auth.accessToken();
      await Future<void>.delayed(Duration.zero);
      expect(provider.authorizations, 1);
      provider.pendingToken!.complete('fresh');
      expect(await first, 'fresh');
      expect(await second, 'fresh');
      expect(provider.interactiveRequests, [false]);
    },
  );
  test(
    'token request should preserve the linked account when consent is required',
    () async {
      await auth.signIn();
      provider.tokenError = const AccountException(
        AccountFailure.interactionRequired,
        'Consent required',
      );
      await expectLater(
        auth.accessToken(rejectedToken: 'token'),
        throwsA(isA<AccountException>()),
      );
      expect(auth.signedIn, isTrue);
      expect(auth.requiresReconnect, isTrue);
      expect(provider.forgets, 0);
      expect(provider.interactiveRequests, [false]);
    },
  );
  test(
    'reconnect should clear the warning when authorization succeeds',
    () async {
      await auth.signIn();
      final originalClient = auth.client;
      await auth.invalidateSession();
      await auth.requestAuthorization();
      expect(auth.requiresReconnect, isFalse);
      expect(identical(originalClient, auth.client), isTrue);
    },
  );
  test(
    'sign out should forget only the app connection when cleanup fails',
    () async {
      await auth.signIn();
      provider.forgetError = StateError('offline');
      await auth.signOut();
      expect(auth.signedIn, isFalse);
      expect(auth.client, isNull);
      expect(
        (await SharedPreferences.getInstance()).getString(
          AuthRepository.accountPreference,
        ),
        isNull,
      );
    },
  );
  test('link should retain authorization when post-link sync fails', () async {
    auth.onSignedIn = () async => throw StateError('offline');
    await auth.signIn();
    expect(auth.signedIn, isTrue);
  });
}
