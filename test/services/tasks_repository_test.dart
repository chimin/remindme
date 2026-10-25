import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart';

import 'package:remindme/services/tasks_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('authentication recovery', () {
    late FakeGooglePlatform platform;
    late TasksRepository repo;
    late Directory cache;
    setUp(() async {
      platform = FakeGooglePlatform();
      GoogleSignInPlatform.instance = platform;
      repo = TasksRepository();
      cache = await Directory.systemTemp.createTemp('remindme_auth_');
      SharedPreferences.setMockInitialValues({});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => cache.path,
          );
    });
    tearDown(() async {
      repo.dispose();
      await platform.events.close();
      await Hive.close();
      await cache.delete(recursive: true);
    });
    test(
      'initialize should show signed out state when silent sign in fails',
      () async {
        platform.silentError = StateError('offline');
        await repo.init();
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
        await Future<void>.delayed(Duration.zero);
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
        await Future<void>.delayed(Duration.zero);
        expect(repo.signedIn, isFalse);
        expect(repo.signingIn, isFalse);
      },
    );
    test(
      'API request should return to sign in when credentials expire',
      () async {
        var requests = 0;
        await http.runWithClient(
          () async {
            await repo.signIn();
            await expectLater(
              repo.getTaskLists(),
              throwsA(isA<DetailedApiRequestError>()),
            );
          },
          () => MockClient((request) async {
            requests++;
            return http.Response(
              '{"error":{"code":401,"message":"expired"}}',
              401,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        expect(requests, 1);
        expect(repo.signedIn, isFalse);
        expect(repo.signingIn, isFalse);
        expect(repo.authError, contains('expired'));
      },
    );
    test(
      'sign in should ignore late authorization when session is invalidated',
      () async {
        final pending = Completer<ClientAuthorizationTokenData?>();
        platform.pendingPermission = pending.future;
        final attempt = repo.signIn();
        await Future<void>.delayed(Duration.zero);
        platform.events.add(AuthenticationEventSignOut());
        await Future<void>.delayed(Duration.zero);
        pending.complete(
          const ClientAuthorizationTokenData(accessToken: 'token'),
        );
        await attempt;
        expect(repo.signedIn, isFalse);
        expect(repo.signingIn, isFalse);
      },
    );
  });
  test(
    'mergeTasks should keep the local entry when it is newer than the remote entry',
    () {
      final nowMs = DateTime(2026, 1, 15, 12, 0, 0).millisecondsSinceEpoch;
      final cached = [
        CachedTask(
          id: 'a',
          tasklistId: 'l',
          title: 'Local',
          updatedAt: nowMs,
          dirty: true,
        ),
      ];
      final remote = [
        Task(
          id: 'a',
          title: 'Remote',
          updated: DateTime(2026, 1, 15, 10, 0, 0).toUtc().toIso8601String(),
        ),
      ];

      final result = mergeTasks(cached, remote, tasklistId: 'l', nowMs: nowMs);

      expect(result, hasLength(1));
      expect(result.first.title, 'Local');
      expect(result.first.dirty, isTrue);
    },
  );

  test(
    'mergeTasks should prefer the remote entry when it is newer than the local entry',
    () {
      final nowMs = DateTime(2026, 1, 15, 12, 0, 0).millisecondsSinceEpoch;
      final cached = [
        CachedTask(
          id: 'a',
          tasklistId: 'l',
          title: 'Local',
          updatedAt: DateTime(2026, 1, 15, 10, 0, 0).millisecondsSinceEpoch,
          dirty: true,
        ),
      ];
      final remote = [
        Task(
          id: 'a',
          title: 'Remote',
          updated: DateTime(2026, 1, 15, 12, 0, 0).toUtc().toIso8601String(),
        ),
      ];

      final result = mergeTasks(cached, remote, tasklistId: 'l', nowMs: nowMs);

      expect(result, hasLength(1));
      expect(result.first.title, 'Remote');
      expect(result.first.dirty, isFalse);
    },
  );

  test(
    'mergeTasks should preserve a locally-requested deletion when newer than the remote entry',
    () {
      final nowMs = DateTime(2026, 1, 15, 12, 0, 0).millisecondsSinceEpoch;
      final cached = [
        CachedTask(
          id: 'a',
          tasklistId: 'l',
          title: 'Local',
          updatedAt: nowMs,
          isDeleted: true,
          dirty: true,
        ),
      ];
      final remote = [
        Task(
          id: 'a',
          title: 'Remote',
          updated: DateTime(2026, 1, 15, 10, 0, 0).toUtc().toIso8601String(),
        ),
      ];

      final result = mergeTasks(cached, remote, tasklistId: 'l', nowMs: nowMs);

      expect(result, hasLength(1));
      expect(result.first.isDeleted, isTrue);
    },
  );

  test('mergeTasks should add remote-only tasks and clear the dirty flag', () {
    final nowMs = DateTime(2026, 1, 15, 12, 0, 0).millisecondsSinceEpoch;
    final cached = <CachedTask>[];
    final remote = [
      Task(
        id: 'b',
        title: 'Remote only',
        updated: DateTime(2026, 1, 15, 10, 0, 0).toUtc().toIso8601String(),
      ),
    ];

    final result = mergeTasks(cached, remote, tasklistId: 'l', nowMs: nowMs);

    expect(result, hasLength(1));
    expect(result.first.id, 'b');
    expect(result.first.title, 'Remote only');
    expect(result.first.dirty, isFalse);
    expect(result.first.isDeleted, isFalse);
  });

  test(
    'mergeTasks should keep local-only entries that are not present remotely',
    () {
      final nowMs = DateTime(2026, 1, 15, 12, 0, 0).millisecondsSinceEpoch;
      final cached = [
        CachedTask(
          id: 'a',
          tasklistId: 'l',
          title: 'Local only',
          updatedAt: nowMs,
        ),
      ];
      final remote = <Task>[];

      final result = mergeTasks(cached, remote, tasklistId: 'l', nowMs: nowMs);

      expect(result, hasLength(1));
      expect(result.first.id, 'a');
      expect(result.first.title, 'Local only');
    },
  );
}

class FakeGooglePlatform extends GoogleSignInPlatform {
  static const user = GoogleSignInUserData(
    email: 'test@example.com',
    id: 'user',
  );
  static const tokens = AuthenticationTokenData(idToken: 'id');
  final events = StreamController<AuthenticationEvent>();
  Object? initializationError;
  bool requireConsent = false;
  Object? authError;
  Object? silentError;
  Object? permissionError;
  Future<ClientAuthorizationTokenData?>? pendingPermission;
  @override
  Stream<AuthenticationEvent> get authenticationEvents => events.stream;
  @override
  Future<void> init(InitParameters params) async {
    if (initializationError != null) throw initializationError!;
  }

  @override
  Future<AuthenticationResults?> attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) async {
    if (silentError != null) throw silentError!;
    return null;
  }

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    if (authError != null) throw authError!;
    return const AuthenticationResults(
      user: user,
      authenticationTokens: tokens,
    );
  }

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async {
    if (requireConsent && !params.request.promptIfUnauthorized) return null;
    if (permissionError != null) throw permissionError!;
    if (pendingPermission != null) return pendingPermission;
    return const ClientAuthorizationTokenData(accessToken: 'token');
  }

  @override
  bool supportsAuthenticate() => true;
  @override
  bool authorizationRequiresUserInteraction() => false;
  @override
  Future<void> disconnect(DisconnectParams params) async {}
  @override
  Future<void> signOut(SignOutParams params) async {}
  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;
}
