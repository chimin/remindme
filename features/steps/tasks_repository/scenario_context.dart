// ignore_for_file: invalid_use_of_visible_for_testing_member

import '../scenario_runner.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remindme/services/google_account_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:googleapis/tasks/v1.dart';

import 'package:remindme/services/tasks_repository.dart';
import 'package:remindme/services/auth_repository.dart';

import '../../../test/support/fake_account_provider.dart';
import 'package:remindme/services/sync_service.dart';
import 'package:remindme/models/task_metadata.dart';

ScenarioCases defineScenarios() {
  final scenarios = <String, ScenarioFactory>{};

  TestWidgetsFlutterBinding.ensureInitialized();
  {
    late TasksRepository repo;
    late AuthRepository auth;
    late Directory cache;
    late FakeTasksServer server;
    late DateTime due;

    Future<void> prepareScenario() async {
      auth = AuthRepository(provider: FakeAccountProvider());
      repo = TasksRepository(authRepository: auth);
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
    }

    Future<void> cleanupScenario() async {
      repo.dispose();
      auth.dispose();
      await Hive.close();
      await cache.delete(recursive: true);
    }

    Future<void> run(Future<void> Function() action) =>
        http.runWithClient(() async {
          await repo.init();
          await repo.signIn();
          await repo.saveCacheEntries('list', [
            CachedTask.fromTask(Task.fromJson(server.tasks['old']!), 'list'),
          ]);
          await action();
        }, () => MockClient(server.handle));

    scenarios['0'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      await run(() async {});
      state.next = () => http.runWithClient(() async {
        final snapshots = <Map<dynamic, dynamic>>[];
        const channel = MethodChannel('chimin.remindme/reminders');
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, (call) async {
              if (call.method == 'replace') {
                snapshots.add(call.arguments as Map);
              }
              return null;
            });
        addTearDown(
          () => TestDefaultBinaryMessengerBinding
              .instance
              .defaultBinaryMessenger
              .setMockMethodCallHandler(channel, null),
        );
        server.offline = true;
        await repo.saveCacheEntries('other', [
          CachedTask(id: 'other', tasklistId: 'other', title: 'Other list'),
        ]);
        await repo.refreshReminders();
        state.next = () => http.runWithClient(() async {
          expect(
            (snapshots.last['tasks'] as List).single['title'],
            'Water plants',
          );
          state.next = () => http.runWithClient(() async {
            await repo.selectTasklist('other');
            state.next = () => http.runWithClient(() async {
              expect(
                (snapshots.last['tasks'] as List).single['title'],
                'Other list',
              );
              state.next = () => http.runWithClient(() async {
                await repo.saveCacheEntries('other', [
                  CachedTask(
                    id: 'other',
                    tasklistId: 'other',
                    title: 'Changed',
                    completed: true,
                  ),
                ]);
                state.next = () => http.runWithClient(() async {
                  expect(
                    (snapshots.last['tasks'] as List).single['completed'],
                    true,
                  );
                  state.next = () => http.runWithClient(() async {
                    await repo.signOut();
                    state.next = () => http.runWithClient(() async {
                      expect(snapshots.last['active'], false);
                      expect(snapshots.last['tasks'], isEmpty);
                    }, () => MockClient(server.handle));
                  }, () => MockClient(server.handle));
                }, () => MockClient(server.handle));
              }, () => MockClient(server.handle));
            }, () => MockClient(server.handle));
          }, () => MockClient(server.handle));
        }, () => MockClient(server.handle));
      }, () => MockClient(server.handle));
    };

    scenarios['1'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      state.next = () async {
        await repo.init();
        state.next = () async {
          expect(repo.initialized, isTrue);
          expect(repo.signedIn, isFalse);
          expect(Hive.isBoxOpen('remindme_tasks_cache'), isFalse);
          expect(
            await File('${cache.path}/remindme_tasks_cache.hive').exists(),
            isFalse,
          );
        };
      };
    };

    scenarios['2'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      await run(() async {});
      state.next = () => http.runWithClient(() async {
        await repo.saveCacheEntries('empty', []);
        server.events.clear();
        state.next = () => http.runWithClient(() async {
          expect(await repo.hasCachedTasks('empty'), isTrue);
          expect(await repo.getTasks('empty'), isEmpty);
          expect(server.events, isEmpty);
        }, () => MockClient(server.handle));
      }, () => MockClient(server.handle));
    };

    scenarios['3'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      await run(() async {});
      state.next = () => http.runWithClient(() async {
        server.offline = true;
        server.events.clear();
        final tasks = await repo.getCachedTasks('list');
        state.next = () => http.runWithClient(() async {
          expect(tasks.single.title, 'Water plants');
          expect(server.events, isEmpty);
        }, () => MockClient(server.handle));
      }, () => MockClient(server.handle));
    };

    scenarios['4'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      await run(() async {});
      state.next = () => http.runWithClient(() async {
        await repo.completeTask('list', 'old', true);
        final entries = await repo.getCacheEntries('list');
        state.next = () => http.runWithClient(() async {
          expect(entries, hasLength(2));
          state.next = () => http.runWithClient(() async {
            final old = entries.singleWhere((e) => e.id == 'old');
            final next = entries.singleWhere((e) => e.id != 'old');
            state.next = () => http.runWithClient(() async {
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
              state.next = () => http.runWithClient(() async {
                final metadata = TaskMetadata.parse(next.notes);
                state.next = () => http.runWithClient(() async {
                  expect(metadata.notes, 'Keep the soil moist');
                  expect(metadata.data['futureFeature'], {'color': 'green'});
                  expect(metadata.data['previousOccurrenceId'], 'old');
                  expect(
                    metadata.data['seriesId'],
                    TaskMetadata.parse(old.notes).data['seriesId'],
                  );
                  expect(
                    TaskMetadata.parse(old.notes).data['nextOccurrenceId'],
                    next.id,
                  );
                  expect(server.tasks['old']!['status'], 'completed');
                  expect(server.tasks['old']!['completed'], isNotNull);
                  expect(server.events, [
                    'PATCH old',
                    'GET',
                    'POST',
                    'PATCH old',
                  ]);
                  expect(entries.every((e) => !e.dirty), isTrue);
                }, () => MockClient(server.handle));
              }, () => MockClient(server.handle));
            }, () => MockClient(server.handle));
          }, () => MockClient(server.handle));
        }, () => MockClient(server.handle));
      }, () => MockClient(server.handle));
    };

    scenarios['5'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      await run(() async {});
      state.next = () => http.runWithClient(() async {
        final old = (await repo.getCachedTasks('list')).single;
        await repo.updateTask(
          'list',
          'old',
          title: 'Edited title',
          notes: old.notes,
          due: DateTime.parse(old.due!),
          completed: true,
        );
        final completed = (await repo.getCacheEntries(
          'list',
        )).singleWhere((entry) => entry.id == 'old');
        state.next = () => http.runWithClient(() async {
          expect(completed.completed, isTrue);
          expect(completed.title, 'Edited title');
          expect(server.creates, 1);
          state.next = () => http.runWithClient(() async {
            final next = (await repo.getCacheEntries(
              'list',
            )).singleWhere((entry) => entry.id != 'old');
            state.next = () => http.runWithClient(() async {
              expect(next.title, 'Edited title');
              state.next = () => http.runWithClient(() async {
                await repo.completeTask('list', 'old', false);
                final reopened = (await repo.getCacheEntries(
                  'list',
                )).singleWhere((entry) => entry.id == 'old');
                state.next = () => http.runWithClient(() async {
                  expect(reopened.completed, isFalse);
                  expect(reopened.status, 'needsAction');
                  expect(reopened.title, completed.title);
                  expect(reopened.notes, completed.notes);
                  expect(reopened.due, completed.due);
                  expect(server.creates, 1);
                  expect(await repo.getCacheEntries('list'), hasLength(2));
                }, () => MockClient(server.handle));
              }, () => MockClient(server.handle));
            }, () => MockClient(server.handle));
          }, () => MockClient(server.handle));
        }, () => MockClient(server.handle));
      }, () => MockClient(server.handle));
    };

    scenarios['6'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      await run(() async {});
      state.next = () => http.runWithClient(() async {
        await Future.wait([
          repo.completeTask('list', 'old', true),
          repo.completeTask('list', 'old', true),
          repo.pullFromRemote('list'),
        ]);
        state.next = () => http.runWithClient(() async {
          expect(server.creates, 1);
          expect(await repo.getCacheEntries('list'), hasLength(2));
        }, () => MockClient(server.handle));
      }, () => MockClient(server.handle));
    };

    scenarios['7'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      await run(() async {});
      state.next = () => http.runWithClient(() async {
        server.offline = true;
        await repo.completeTask('list', 'old', true);
        final pending = await repo.getCacheEntries('list');
        state.next = () => http.runWithClient(() async {
          expect(pending, hasLength(2));
          expect(pending.every((e) => e.dirty), isTrue);
          expect(server.creates, 0);
          state.next = () => http.runWithClient(() async {
            final plannedDue = pending.singleWhere((e) => e.id == null).due;
            repo.dispose();
            auth.dispose();
            auth = AuthRepository(provider: FakeAccountProvider());
            await Hive.close();
            repo = TasksRepository(authRepository: auth);
            await repo.init();
            await repo.signIn();
            server.offline = false;
            await SyncService(repo).sync();
            final recovered = await repo.getCacheEntries('list');
            state.next = () => http.runWithClient(() async {
              expect(recovered, hasLength(2));
              expect(recovered.every((e) => !e.dirty), isTrue);
              expect(
                recovered.singleWhere((e) => !e.completed).due,
                plannedDue,
              );
              expect(server.creates, 1);
            }, () => MockClient(server.handle));
          }, () => MockClient(server.handle));
        }, () => MockClient(server.handle));
      }, () => MockClient(server.handle));
    };

    scenarios['8'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      await run(() async {});
      state.next = () => http.runWithClient(() async {
        server.loseCreateResponse = true;
        await repo.completeTask('list', 'old', true);
        state.next = () => http.runWithClient(() async {
          expect(server.creates, 1);
          state.next = () => http.runWithClient(() async {
            final pending = (await repo.getCacheEntries(
              'list',
            )).singleWhere((e) => e.id == null);
            await SyncService(repo).sync();
            state.next = () => http.runWithClient(() async {
              expect(server.creates, 1);
              state.next = () => http.runWithClient(() async {
                final recovered = await repo.getCacheEntries('list');
                state.next = () => http.runWithClient(() async {
                  expect(recovered, hasLength(2));
                  expect(
                    recovered.singleWhere((e) => !e.completed).due,
                    pending.due,
                  );
                  expect(recovered.every((e) => !e.dirty), isTrue);
                }, () => MockClient(server.handle));
              }, () => MockClient(server.handle));
            }, () => MockClient(server.handle));
          }, () => MockClient(server.handle));
        }, () => MockClient(server.handle));
      }, () => MockClient(server.handle));
    };

    scenarios['9'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      await run(() async {});
      state.next = () => http.runWithClient(() async {
        server.tasks['old']!['status'] = 'completed';
        server.tasks['old']!['updated'] = DateTime.now()
            .toUtc()
            .add(const Duration(seconds: 1))
            .toIso8601String();
        await repo.pullFromRemote('list');
        state.next = () => http.runWithClient(() async {
          expect(server.creates, 1);
          expect(server.lastListQuery['showHidden'], 'true');
          expect(
            (await repo.getCacheEntries('list')).where((e) => e.completed),
            hasLength(1),
          );
        }, () => MockClient(server.handle));
      }, () => MockClient(server.handle));
    };

    scenarios['10'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      await run(() async {});
      state.next = () => http.runWithClient(() async {
        await repo.completeTask('list', 'old', true);
        server.tasks.removeWhere((id, _) => id != 'old');
        await repo.saveCacheEntries('list', []);
        await repo.pullFromRemote('list');
        state.next = () => http.runWithClient(() async {
          expect(server.creates, 1);
          expect(await repo.getCacheEntries('list'), hasLength(1));
        }, () => MockClient(server.handle));
      }, () => MockClient(server.handle));
    };

    scenarios['11'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      await run(() async {});
      state.next = () => http.runWithClient(() async {
        await repo.completeTask('list', 'old', true);
        final first = (await repo.getCacheEntries(
          'list',
        )).singleWhere((e) => !e.completed);
        await repo.completeTask('list', first.id!, true);
        final entries = await repo.getCacheEntries('list');
        state.next = () => http.runWithClient(() async {
          expect(entries.where((e) => e.completed), hasLength(2));
          state.next = () => http.runWithClient(() async {
            final next = entries.singleWhere((e) => !e.completed);
            state.next = () => http.runWithClient(() async {
              expect(DateTime.parse(next.due!), DateTime.utc(due.year, 3, 31));
              expect(
                TaskMetadata.parse(next.notes).data['seriesId'],
                'list:old',
              );
              expect(
                TaskMetadata.parse(next.notes).data['previousOccurrenceId'],
                first.id,
              );
              expect(
                TaskMetadata.parse(next.notes).data['nextOccurrenceId'],
                isNull,
              );
            }, () => MockClient(server.handle));
          }, () => MockClient(server.handle));
        }, () => MockClient(server.handle));
      }, () => MockClient(server.handle));
    };

    scenarios['12'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      await run(() async {});
      state.next = () => http.runWithClient(() async {
        final entry = (await repo.getCacheEntries(
          'list',
        )).single.copyWith(notes: 'Plain notes');
        await repo.saveCacheEntries('list', [entry]);
        await repo.completeTask('list', 'old', true);
        state.next = () => http.runWithClient(() async {
          expect(server.creates, 0);
          expect((await repo.getCacheEntries('list')).single.completed, isTrue);
        }, () => MockClient(server.handle));
      }, () => MockClient(server.handle));
    };
  }
  {
    late TasksRepository repo;
    late AuthRepository auth;
    late FakeAccountProvider provider;
    late Directory cache;
    Future<void> prepareScenario() async {
      SharedPreferences.setMockInitialValues({});
      cache = await Directory.systemTemp.createTemp('remindme_connection_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => cache.path,
          );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('home_widget'),
            (_) async => true,
          );
      provider = FakeAccountProvider();
      auth = AuthRepository(provider: provider);
      repo = TasksRepository(authRepository: auth);
    }

    Future<void> cleanupScenario() async {
      await repo.close();
      repo.dispose();
      auth.dispose();
      await Hive.close();
      await cache.delete(recursive: true);
    }

    scenarios['13'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      state.next = () async {
        var requests = 0;
        await http.runWithClient(
          () async {
            await repo.init();
            await repo.signIn();
            await expectLater(
              repo.getTaskLists(),
              throwsA(isA<AccountException>()),
            );
          },
          () => MockClient((_) async {
            requests++;
            return http.Response(
              '{"error":{"code":401,"message":"expired"}}',
              401,
            );
          }),
        );
        state.next = () async {
          expect(requests, 2);
          expect(repo.signedIn, isTrue);
          expect(repo.requiresReconnect, isTrue);
          expect(provider.forgets, 0);
        };
      };
    };
    scenarios['14'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      state.next = () async {
        await repo.init();
        await repo.signIn();
        await repo.selectTasklist('list');
        await repo.saveCacheEntries('list', [
          CachedTask(
            id: null,
            tasklistId: 'legacy',
            localId: 'pending',
            title: 'Private',
            updatedAt: 1,
            dirty: true,
          ),
        ]);
        provider.forgetError = StateError('offline');
        await repo.signOut();
        state.next = () async {
          expect(repo.hasLinkedAccount, isFalse);
          expect(repo.selectedTasklistId, isNull);
          expect(await repo.getCacheEntries('list'), isEmpty);
          expect(
            (await SharedPreferences.getInstance()).getString(
              AuthRepository.accountPreference,
            ),
            isNull,
          );
        };
      };
    };
    scenarios['15'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      state.next = () async {
        await http.runWithClient(
          () async {
            await repo.init();
            await repo.signIn();
            final created = await repo.createTask('list', title: 'Offline');
            expect(created.id, startsWith('local-'));
            await repo.updateTask('list', created.id!, title: 'Edited offline');
            expect(
              (await repo.getCachedTasks('list')).single.title,
              'Edited offline',
            );
            await repo.completeTask('list', created.id!, true);
            expect(
              (await repo.getCachedTasks('list')).single.status,
              'completed',
            );
            expect(repo.syncPending, isTrue);
            await repo.deleteTask('list', created.id!);
            expect(await repo.getCacheEntries('list'), isEmpty);
          },
          () => MockClient((_) async => throw const SocketException('offline')),
        );
        state.next = () async {};
      };
    };
    scenarios['16'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      state.next = () async {
        var offline = true;
        var row = <String, dynamic>{
          'id': 'server',
          'title': 'Offline',
          'status': 'needsAction',
          'updated': DateTime.now().toUtc().toIso8601String(),
        };
        final paths = <String>[];
        await http.runWithClient(
          () async {
            await repo.init();
            await repo.signIn();
            final local = await repo.createTask('list', title: 'Offline');
            offline = false;
            await repo.pushCreate(
              'list',
              (await repo.getCacheEntries('list')).single,
            );
            await repo.pullFromRemote('list');
            await repo.updateTask(
              'list',
              local.id!,
              title: 'Edited after sync',
            );
            expect(
              (await repo.getCachedTasks('list')).single.title,
              'Edited after sync',
            );
            await repo.deleteTask('list', local.id!);
            expect(await repo.getCacheEntries('list'), isEmpty);
          },
          () => MockClient((request) async {
            if (offline) throw const SocketException('offline');
            paths.add('${request.method} ${request.url.pathSegments.last}');
            if (request.method == 'DELETE') return http.Response('', 204);
            if (request.method == 'GET') {
              return http.Response(
                jsonEncode({
                  'items': [row],
                }),
                200,
                headers: {'content-type': 'application/json'},
              );
            }
            row = {...row, ...jsonDecode(request.body) as Map<String, dynamic>};
            return http.Response(
              jsonEncode(row),
              200,
              headers: {'content-type': 'application/json'},
            );
          }),
        );
        state.next = () async {
          expect(paths, containsAllInOrder(['PATCH server', 'DELETE server']));
        };
      };
    };

    scenarios['17'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      state.next = () async {
        await repo.init();
        await repo.selectTasklist('legacy');
        await repo.saveCacheEntries('legacy', [
          CachedTask(
            id: null,
            tasklistId: 'legacy',
            localId: 'pending',
            title: 'Private',
            updatedAt: 1,
            dirty: true,
          ),
        ]);
        await http.runWithClient(
          () => repo.signIn(),
          () => MockClient((_) async => http.Response('', 404)),
        );
        state.next = () async {
          expect(repo.hasLinkedAccount, isFalse);
          expect(
            (await repo.getCacheEntries('legacy')).single.title,
            'Private',
          );
          expect(repo.authError, contains('owns your saved task list'));
        };
      };
    };
    scenarios['18'] = (state) async {
      addTearDown(cleanupScenario);
      await prepareScenario();
      state.next = () async {
        await repo.init();
        await repo.selectTasklist('legacy');
        await repo.saveCacheEntries('legacy', [
          CachedTask(
            id: null,
            tasklistId: 'legacy',
            localId: 'pending',
            title: 'Private',
            updatedAt: 1,
            dirty: true,
          ),
        ]);
        await http.runWithClient(
          () => repo.signIn(),
          () => MockClient((_) async => http.Response('{"id":"legacy"}', 200)),
        );
        state.next = () async {
          expect(repo.hasLinkedAccount, isTrue);
          expect((await repo.getCacheEntries('legacy')).single.dirty, isTrue);
        };
      };
    };
  }

  scenarios['19'] = (state) async {
    state.next = () async {
      final auth = FakeAuthRepository();
      final repo = TasksRepository(authRepository: auth);
      var notifications = 0;
      repo.addListener(() => notifications++);
      var synced = false;
      repo.onSignedIn = () async {
        expect((await repo.getTaskLists()).single.id, 'list');
        synced = true;
      };
      await repo.signIn();
      state.next = () async {
        expect(repo.signedIn, isTrue);
        expect(repo.userEmail, 'test@example.com');
        expect(synced, isTrue);
        expect(notifications, greaterThan(0));
        state.next = () async {
          repo.dispose();
          final previousNotifications = notifications;
          state.next = () async {
            expect(auth.disposed, isFalse);
            state.next = () async {
              // The external owner can continue using auth after the facade is disposed.
              auth.onSignedIn = null;
              await auth.signIn();
              state.next = () async {
                expect(notifications, previousNotifications);
                auth.dispose();
              };
            };
          };
        };
      };
    };
  };

  scenarios['20'] = (state) async {
    state.next = () async {
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
      state.next = () async {
        expect(result, hasLength(1));
        expect(result.first.title, 'Local');
        expect(result.first.dirty, isTrue);
      };
    };
  };

  scenarios['21'] = (state) async {
    state.next = () async {
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
      state.next = () async {
        expect(result, hasLength(1));
        expect(result.first.title, 'Remote');
        expect(result.first.dirty, isFalse);
      };
    };
  };

  scenarios['22'] = (state) async {
    state.next = () async {
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
      state.next = () async {
        expect(result, hasLength(1));
        expect(result.first.isDeleted, isTrue);
      };
    };
  };

  scenarios['23'] = (state) async {
    state.next = () async {
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
      state.next = () async {
        expect(result, hasLength(1));
        expect(result.first.id, 'b');
        expect(result.first.title, 'Remote only');
        expect(result.first.dirty, isFalse);
        expect(result.first.isDeleted, isFalse);
      };
    };
  };

  scenarios['24'] = (state) async {
    state.next = () async {
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
      state.next = () async {
        expect(result, hasLength(1));
        expect(result.first.id, 'a');
        expect(result.first.title, 'Local only');
      };
    };
  };

  return scenarios;
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

class FakeAuthRepository extends AuthRepository {
  http.Client? _client;
  bool disposed = false;

  @override
  http.Client? get client => _client;
  @override
  bool get signedIn => _client != null;
  @override
  String? get userEmail => 'test@example.com';

  @override
  Future<void> signIn() async {
    _client?.close();
    _client = MockClient(
      (_) async => http.Response(
        '{"items":[{"id":"list","title":"Tasks"}]}',
        200,
        headers: {'content-type': 'application/json'},
      ),
    );
    notifyListeners();
    await onSignedIn?.call();
  }

  @override
  void dispose() {
    disposed = true;
    _client?.close();
    super.dispose();
  }
}
