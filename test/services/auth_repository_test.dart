import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:remindme/services/auth_repository.dart';

import '../support/fake_google_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('authentication recovery', () {
    late FakeGooglePlatform platform;
    late AuthRepository repo;
    setUp(() async {
      platform = FakeGooglePlatform();
      GoogleSignInPlatform.instance = platform;
      repo = AuthRepository();
      SharedPreferences.setMockInitialValues({});
    });
    tearDown(() async {
      repo.dispose();
      await platform.events.close();
    });
    Future<void> settleAuthentication() async {
      // Deliver queued platform events, then wait for asynchronous cleanup.
      await Future<void>.delayed(Duration.zero);
      if (!repo.signingIn) return;
      final idle = Completer<void>();
      void listener() {
        if (!repo.signingIn && !idle.isCompleted) idle.complete();
      }

      repo.addListener(listener);
      try {
        await idle.future;
      } finally {
        repo.removeListener(listener);
      }
    }

    Future<bool?> savedSuccess() async =>
        (await SharedPreferences.getInstance()).getBool(
          'remindme_sign_in_succeeded',
        );

    Future<void> restart() async {
      repo.dispose();
      await platform.events.close();
      platform = FakeGooglePlatform()
        ..restoreUser = platform.restoreUser
        ..silentAttempts = platform.silentAttempts
        ..signOutCalls = platform.signOutCalls;
      GoogleSignInPlatform.instance = platform;
      repo = AuthRepository();
      await repo.init();
    }

    void emitSignIn() {
      platform.events.add(
        AuthenticationEventSignIn(
          user: FakeGooglePlatform.user,
          authenticationTokens: FakeGooglePlatform.tokens,
        ),
      );
    }

    test(
      'initialize should clear leftover sessions when no successful sign in was saved',
      () async {
        platform.restoreUser = true;
        await repo.init();
        expect(platform.silentAttempts, 0);
        expect(platform.signOutCalls, 1);
        expect(repo.signedIn, isFalse);
        expect(await savedSuccess(), isFalse);
        emitSignIn();
        await settleAuthentication();
        expect(repo.signedIn, isFalse);
      },
    );

    test(
      'initialize should restore the previous session when sign in succeeded',
      () async {
        await repo.signIn();
        expect(await savedSuccess(), isTrue);
        platform.restoreUser = true;
        await restart();
        expect(platform.silentAttempts, 1);
        expect(repo.signedIn, isTrue);
        expect(await savedSuccess(), isTrue);
      },
    );

    test(
      'initialize should accept a restore event when the platform returns no future',
      () async {
        SharedPreferences.setMockInitialValues({
          'remindme_sign_in_succeeded': true,
        });
        platform.eventOnlyRestore = true;
        await repo.init();
        expect(repo.signedIn, isFalse);
        expect(repo.signingIn, isFalse);
        emitSignIn();
        await settleAuthentication();
        expect(repo.signedIn, isTrue);
        expect(await savedSuccess(), isTrue);
      },
    );

    test(
      'initialize should clear a failed restore when the platform reports an event error',
      () async {
        SharedPreferences.setMockInitialValues({
          'remindme_sign_in_succeeded': true,
        });
        platform.eventOnlyRestore = true;
        await repo.init();
        platform.events.add(
          AuthenticationEventException(
            const GoogleSignInException(
              code: GoogleSignInExceptionCode.interrupted,
            ),
          ),
        );
        await settleAuthentication();
        emitSignIn();
        await settleAuthentication();
        expect(repo.signedIn, isFalse);
        expect(repo.signingIn, isFalse);
        expect(await savedSuccess(), isFalse);
        expect(platform.signOutCalls, 1);
      },
    );

    test(
      'initialize should clear saved success when no Google session remains',
      () async {
        await repo.signIn();
        await restart();
        expect(platform.silentAttempts, 1);
        expect(repo.signedIn, isFalse);
        expect(await savedSuccess(), isFalse);
        await restart();
        expect(platform.silentAttempts, 1);
      },
    );

    test(
      'initialize should skip restoration when a later sign in failed',
      () async {
        await repo.signIn();
        platform.authError = StateError('offline');
        await repo.signIn();
        expect(await savedSuccess(), isFalse);
        final signOuts = platform.signOutCalls;
        platform.restoreUser = true;
        await restart();
        expect(platform.silentAttempts, 0);
        expect(platform.signOutCalls, signOuts + 1);
        expect(repo.signedIn, isFalse);
      },
    );

    test(
      'sign in should clear the session when authentication is canceled',
      () async {
        platform.authError = const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
        );
        await repo.signIn();
        expect(platform.signOutCalls, 2);
        expect(platform.disconnectCalls, 0);
        expect(await savedSuccess(), isFalse);
        expect(repo.authError, isNull);
        emitSignIn();
        await settleAuthentication();
        expect(repo.signedIn, isFalse);
      },
    );

    test(
      'sign in should block retries when failed session cleanup is pending',
      () async {
        final pending = Completer<void>();
        platform.pendingSignOut = pending.future;
        platform.blockSignOutAfter = 1;
        platform.authError = StateError('offline');
        final attempt = repo.signIn();
        await platform.cleanupStarted.future;
        expect(repo.signingIn, isTrue);
        expect(await savedSuccess(), isFalse);
        emitSignIn();
        await repo.signIn();
        expect(platform.manualAttempts, 1);
        pending.complete();
        await attempt;
        expect(repo.signingIn, isFalse);
        expect(repo.signedIn, isFalse);
        expect(repo.authError, isNotNull);
        platform.pendingSignOut = null;
        platform.authError = null;
        await repo.signIn();
        expect(repo.signedIn, isTrue);
        expect(await savedSuccess(), isTrue);
      },
    );

    test(
      'sign in should keep restoration disabled when Google cleanup fails',
      () async {
        platform.signOutError = StateError('cleanup failed');
        await repo.signIn();
        expect(repo.signingIn, isFalse);
        expect(repo.signedIn, isFalse);
        expect(await savedSuccess(), isFalse);
        emitSignIn();
        await settleAuthentication();
        expect(repo.signedIn, isFalse);
        platform.signOutError = null;
        platform.restoreUser = true;
        await restart();
        expect(platform.silentAttempts, 0);
        await repo.signIn();
        expect(repo.signedIn, isTrue);
      },
    );

    test(
      'sign in should ignore stale events when a failed attempt returned to login',
      () async {
        platform.permissionError = StateError('denied');
        await repo.signIn();
        expect(platform.signOutCalls, 2);
        expect(await savedSuccess(), isFalse);
        platform.permissionError = null;
        emitSignIn();
        await settleAuthentication();
        expect(repo.signedIn, isFalse);
        expect(platform.manualAttempts, 1);
        expect(await savedSuccess(), isFalse);
      },
    );

    test(
      'initialize should skip restoration when the user signed out',
      () async {
        await repo.init();
        await repo.signIn();
        await repo.signOut();
        platform.restoreUser = true;
        await restart();
        expect(platform.silentAttempts, 0);
        expect(repo.signedIn, isFalse);
        expect(await savedSuccess(), isFalse);
      },
    );

    test(
      'authentication event should clear saved success when Google signs out',
      () async {
        await repo.signIn();
        platform.events.add(AuthenticationEventSignOut());
        await settleAuthentication();
        expect(repo.signedIn, isFalse);
        expect(await savedSuccess(), isFalse);
      },
    );

    test(
      'initialize should show signed out state when silent sign in fails',
      () async {
        SharedPreferences.setMockInitialValues({
          'remindme_sign_in_succeeded': true,
        });
        platform.silentError = StateError('offline');
        await repo.init();
        expect(platform.silentAttempts, 1);
        expect(
          (await SharedPreferences.getInstance()).getBool(
            'remindme_sign_in_succeeded',
          ),
          isFalse,
        );
        expect(repo.initialized, isTrue);
        expect(repo.signedIn, isFalse);
        expect(repo.signingIn, isFalse);
      },
    );
    test(
      'initialize should allow retry when Google initialization fails',
      () async {
        platform.initializationError = StateError('unavailable');
        await repo.init();
        expect(repo.initialized, isTrue);
        expect(repo.signedIn, isFalse);
        expect(repo.signingIn, isFalse);
        platform.initializationError = null;
        await repo.signIn();
        expect(repo.signedIn, isTrue);
      },
    );
    test('sign in should allow retry when authentication fails', () async {
      platform.authError = StateError('offline');
      await repo.signIn();
      expect(repo.signedIn, isFalse);
      expect(repo.signingIn, isFalse);
      expect(repo.authError, isNotNull);
      platform.authError = null;
      await repo.signIn();
      expect(repo.signedIn, isTrue);
      expect(repo.authError, isNull);
    });
    test(
      'sign in should silently return signed out when user cancels',
      () async {
        platform.authError = const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
        );
        await repo.signIn();
        expect(repo.signedIn, isFalse);
        expect(repo.signingIn, isFalse);
        expect(repo.authError, isNull);
      },
    );
    test(
      'sign in should clear partial credentials when permission is denied',
      () async {
        platform.requireConsent = true;
        platform.permissionError = StateError('denied');
        await repo.signIn();
        expect(repo.signedIn, isFalse);
        expect(repo.userEmail, isNull);
        expect(repo.signingIn, isFalse);
        platform.permissionError = null;
        await repo.signIn();
        expect(repo.signedIn, isTrue);
      },
    );
    test(
      'sign in should preserve credentials when initial sync fails',
      () async {
        repo.onSignedIn = () async => throw StateError('sync failed');
        await repo.signIn();
        expect(repo.signedIn, isTrue);
        expect(repo.signingIn, isFalse);
        expect(await savedSuccess(), isTrue);
      },
    );
    test(
      'authentication event should recover when authorization fails',
      () async {
        await repo.signIn();
        platform.permissionError = StateError('denied');
        platform.events.add(
          AuthenticationEventSignIn(
            user: FakeGooglePlatform.user,
            authenticationTokens: FakeGooglePlatform.tokens,
          ),
        );
        await settleAuthentication();
        expect(repo.signedIn, isFalse);
        expect(repo.signingIn, isFalse);
        expect(repo.authError, isNotNull);
      },
    );
    test(
      'authentication event should clear credentials when stream reports an error',
      () async {
        await repo.signIn();
        platform.events.add(
          AuthenticationEventException(
            const GoogleSignInException(
              code: GoogleSignInExceptionCode.interrupted,
            ),
          ),
        );
        await settleAuthentication();
        expect(repo.signedIn, isFalse);
        expect(repo.signingIn, isFalse);
      },
    );
    test(
      'invalidate session should clear saved success when credentials expire',
      () async {
        await repo.signIn();
        await repo.invalidateSession();
        expect(repo.signedIn, isFalse);
        expect(repo.signingIn, isFalse);
        expect(repo.client, isNull);
        expect(repo.authError, contains('expired'));
        expect(await savedSuccess(), isFalse);
        expect(platform.signOutCalls, 2);
      },
    );

    test('client should authorize requests when sign in succeeds', () async {
      await http.runWithClient(
        () async {
          await repo.signIn();
          final response = await repo.client!.get(
            Uri.https('example.com', '/tasks'),
          );
          expect(response.statusCode, 200);
        },
        () => MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer token');
          return http.Response('{}', 200);
        }),
      );
      await repo.signOut();
      expect(repo.client, isNull);
    });

    test(
      'sign in should ignore late authorization when session is invalidated',
      () async {
        final pending = Completer<ClientAuthorizationTokenData?>();
        platform.pendingPermission = pending.future;
        final attempt = repo.signIn();
        await platform.permissionStarted.future;
        platform.events.add(AuthenticationEventSignOut());
        await settleAuthentication();
        pending.complete(
          const ClientAuthorizationTokenData(accessToken: 'token'),
        );
        await attempt;
        expect(repo.signedIn, isFalse);
        expect(repo.signingIn, isFalse);
      },
    );
  });
}
