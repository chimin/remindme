import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart';

import 'package:remindme/services/tasks_repository.dart';
import 'package:remindme/services/sync_service.dart';
import 'package:remindme/models/task_metadata.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('recurring tasks', () {
    late TasksRepository repo;
    late FakeGooglePlatform platform;
    late Directory cache;
    late FakeTasksServer server;
    late DateTime due;

    setUp(() async {
      platform = FakeGooglePlatform();
      GoogleSignInPlatform.instance = platform;
      repo = TasksRepository();
      cache = await Directory.systemTemp.createTemp('remindme_recurrence_');
      SharedPreferences.setMockInitialValues({'remindme_tasklist_id': 'list'});
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => cache.path,
          );
      due = DateTime.utc(DateTime.now().year + 1, 1, 31);
      server = FakeTasksServer();
      server.tasks['old'] = Task(
        id: 'old',
        title: 'Water plants',
        parent: 'parent',
        notes: TaskMetadata('Keep the soil moist', {
          'recurrence': {
            'frequency': 'monthly',
            'interval': 1,
            'anchorDay': 31,
          },
          'futureFeature': {'color': 'green'},
        }).encode(),
        due: due.toIso8601String(),
        status: 'needsAction',
        updated: DateTime.now().toUtc().toIso8601String(),
      ).toJson();
    });
    tearDown(() async {
      repo.dispose();
      await platform.events.close();
      await Hive.close();
      await cache.delete(recursive: true);
    });

    Future<void> run(Future<void> Function() action) =>
        http.runWithClient(() async {
          await repo.init();
          await repo.signIn();
          await repo.saveCacheEntries('list', [
            CachedTask.fromTask(Task.fromJson(server.tasks['old']!), 'list'),
          ]);
          await action();
        }, () => MockClient(server.handle));

    test(
      'complete task should retain history and clone metadata when task repeats',
      () => run(() async {
        await repo.completeTask('list', 'old', true);
        final entries = await repo.getCacheEntries('list');
        expect(entries, hasLength(2));
        final old = entries.singleWhere((e) => e.id == 'old');
        final next = entries.singleWhere((e) => e.id != 'old');
        expect(old.completed, isTrue);
        expect(old.due, due.toIso8601String());
        expect(next.completed, isFalse);
        expect(next.status, 'needsAction');
        expect(next.title, old.title);
        expect(next.parent, 'parent');
        expect(
          DateTime.parse(next.due!),
          DateTime.utc(due.year, 2, DateTime.utc(due.year, 3, 0).day),
        );
        final metadata = TaskMetadata.parse(next.notes);
        expect(metadata.notes, 'Keep the soil moist');
        expect(metadata.data['futureFeature'], {'color': 'green'});
        expect(metadata.data['previousOccurrenceId'], 'old');
        expect(
          metadata.data['seriesId'],
          TaskMetadata.parse(old.notes).data['seriesId'],
        );
        expect(TaskMetadata.parse(old.notes).data['nextOccurrenceId'], next.id);
        expect(server.tasks['old']!['status'], 'completed');
        expect(server.tasks['old']!['completed'], isNotNull);
        expect(server.events, ['PATCH old', 'GET', 'POST', 'PATCH old']);
        expect(entries.every((e) => !e.dirty), isTrue);
      }),
    );

    test(
      'complete task should create one successor when completion requests overlap',
      () => run(() async {
        await Future.wait([
          repo.completeTask('list', 'old', true),
          repo.completeTask('list', 'old', true),
          repo.pullFromRemote('list'),
        ]);
        expect(server.creates, 1);
        expect(await repo.getCacheEntries('list'), hasLength(2));
      }),
    );

    test(
      'sync should recover both writes when completion was saved offline before restart',
      () => run(() async {
        server.offline = true;
        await expectLater(
          repo.completeTask('list', 'old', true),
          throwsA(isA<SocketException>()),
        );
        final pending = await repo.getCacheEntries('list');
        expect(pending, hasLength(2));
        expect(pending.every((e) => e.dirty), isTrue);
        expect(server.creates, 0);
        final plannedDue = pending.singleWhere((e) => e.id == null).due;
        repo.dispose();
        await platform.events.close();
        platform = FakeGooglePlatform();
        GoogleSignInPlatform.instance = platform;
        await Hive.close();
        repo = TasksRepository();
        await repo.init();
        await repo.signIn();
        server.offline = false;
        await SyncService(repo).sync();
        final recovered = await repo.getCacheEntries('list');
        expect(recovered, hasLength(2));
        expect(recovered.every((e) => !e.dirty), isTrue);
        expect(recovered.singleWhere((e) => !e.completed).due, plannedDue);
        expect(server.creates, 1);
      }),
    );

    test(
      'sync should reconcile the existing clone when create response is lost',
      () => run(() async {
        server.loseCreateResponse = true;
        await expectLater(
          repo.completeTask('list', 'old', true),
          throwsA(isA<SocketException>()),
        );
        expect(server.creates, 1);
        final pending = (await repo.getCacheEntries(
          'list',
        )).singleWhere((e) => e.id == null);
        await SyncService(repo).sync();
        expect(server.creates, 1);
        final recovered = await repo.getCacheEntries('list');
        expect(recovered, hasLength(2));
        expect(recovered.singleWhere((e) => !e.completed).due, pending.due);
        expect(recovered.every((e) => !e.dirty), isTrue);
      }),
    );

    test(
      'pull should clone a task when completion happened in Google Tasks',
      () => run(() async {
        server.tasks['old']!['status'] = 'completed';
        server.tasks['old']!['updated'] = DateTime.now()
            .toUtc()
            .add(const Duration(seconds: 1))
            .toIso8601String();
        await repo.pullFromRemote('list');
        expect(server.creates, 1);
        expect(server.lastListQuery['showHidden'], 'true');
        expect(
          (await repo.getCacheEntries('list')).where((e) => e.completed),
          hasLength(1),
        );
      }),
    );

    test(
      'pull should respect a deleted successor when cache is rebuilt',
      () => run(() async {
        await repo.completeTask('list', 'old', true);
        server.tasks.removeWhere((id, _) => id != 'old');
        await repo.saveCacheEntries('list', []);
        await repo.pullFromRemote('list');
        expect(server.creates, 1);
        expect(await repo.getCacheEntries('list'), hasLength(1));
      }),
    );

    test(
      'complete task should retain the series when a successor is completed',
      () => run(() async {
        await repo.completeTask('list', 'old', true);
        final first = (await repo.getCacheEntries(
          'list',
        )).singleWhere((e) => !e.completed);
        await repo.completeTask('list', first.id!, true);
        final entries = await repo.getCacheEntries('list');
        expect(entries.where((e) => e.completed), hasLength(2));
        final next = entries.singleWhere((e) => !e.completed);
        expect(DateTime.parse(next.due!), DateTime.utc(due.year, 3, 31));
        expect(TaskMetadata.parse(next.notes).data['seriesId'], 'list:old');
        expect(
          TaskMetadata.parse(next.notes).data['previousOccurrenceId'],
          first.id,
        );
        expect(TaskMetadata.parse(next.notes).data['nextOccurrenceId'], isNull);
      }),
    );

    test(
      'complete task should keep a single task when recurrence is absent',
      () => run(() async {
        final entry = (await repo.getCacheEntries(
          'list',
        )).single.copyWith(notes: 'Plain notes');
        await repo.saveCacheEntries('list', [entry]);
        await repo.completeTask('list', 'old', true);
        expect(server.creates, 0);
        expect((await repo.getCacheEntries('list')).single.completed, isTrue);
      }),
    );
  });
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

class FakeTasksServer {
  final tasks = <String, Map<String, dynamic>>{};
  final events = <String>[];
  Map<String, String> lastListQuery = {};
  int creates = 0;
  bool offline = false;
  bool loseCreateResponse = false;

  Future<http.Response> handle(http.Request request) async {
    if (offline) throw const SocketException('offline');
    Map<String, dynamic> body;
    switch (request.method) {
      case 'GET':
        events.add('GET');
        lastListQuery = request.url.queryParameters;
        body = {'items': tasks.values.toList()};
      case 'PATCH':
        final id = request.url.pathSegments.last;
        events.add('PATCH $id');
        body = tasks[id]!;
        body.addAll(jsonDecode(request.body) as Map<String, dynamic>);
        body['updated'] = DateTime.now().toUtc().toIso8601String();
        if (body['status'] == 'completed') {
          body['completed'] ??= body['updated'];
        } else {
          body.remove('completed');
        }
      case 'POST':
        events.add('POST');
        final id = 'next-${++creates}';
        body = Map<String, dynamic>.from(jsonDecode(request.body) as Map);
        body['id'] = id;
        body['parent'] = request.url.queryParameters['parent'];
        body['updated'] = DateTime.now().toUtc().toIso8601String();
        tasks[id] = body;
        if (loseCreateResponse) {
          loseCreateResponse = false;
          throw const SocketException('response lost');
        }
      default:
        throw StateError(
          'Unexpected request: ${request.method} ${request.url}',
        );
    }
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
    );
  }
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
