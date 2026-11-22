import '../scenario_runner.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:remindme/services/task_storage_lease.dart';
import 'package:remindme/services/google_account_provider.dart';

import 'package:remindme/services/sync_service.dart';
import 'package:remindme/services/tasks_repository.dart';

class FakeRepo extends TasksRepository {
  String? selectedId = 'list-1';
  final List<CachedTask> entries = <CachedTask>[];
  final List<String> pushedCreates = <String>[];
  final List<String> pushedUpdates = <String>[];
  final List<String> pushedDeletes = <String>[];
  bool pulled = false;
  int pulls = 0;
  Completer<void>? pendingPull;

  @override
  String? get selectedTasklistId => selectedId;

  @override
  Future<List<CachedTask>> getCacheEntries(String tasklistId) async =>
      List<CachedTask>.from(entries);

  @override
  Future<void> pushCreate(String tasklistId, CachedTask entry) async {
    pushedCreates.add(entry.localId!);
    entries.removeWhere((e) => e.localId == entry.localId);
    entries.add(
      CachedTask.fromTask(entry.toTask(), tasklistId).copyWith(dirty: false),
    );
  }

  @override
  Future<void> pushUpdate(String tasklistId, CachedTask entry) async {
    pushedUpdates.add(entry.id!);
  }

  @override
  Future<void> pushDelete(String tasklistId, CachedTask entry) async {
    pushedDeletes.add(entry.id!);
    entries.removeWhere((e) => e.id == entry.id);
  }

  @override
  Future<void> pullFromRemote(String tasklistId) async {
    pulled = true;
    pulls++;
    await pendingPull?.future;
  }
}

class _WorkerRepository extends FakeRepo {
  _WorkerRepository(this.lease);
  final TaskStorageLease lease;
  bool linked = true;
  bool reconnect = false;
  bool closed = false;
  Object? failure;
  @override
  bool get hasLinkedAccount => linked;
  @override
  bool get requiresReconnect => reconnect;
  @override
  Future<void> init() async {
    initialized = true;
  }

  @override
  Future<void> pullFromRemote(String id) async {
    if (failure != null) throw failure!;
    await super.pullFromRemote(id);
  }

  @override
  Future<void> close() async {
    closed = true;
    lease.release();
  }
}

ScenarioCases defineScenarios() {
  final scenarios = <String, ScenarioFactory>{};

  TestWidgetsFlutterBinding.ensureInitialized();
  scenarios['0'] = (state) async {
    state.next = () async {
      final foreground = TaskStorageLease();
      await foreground.acquire();
      var created = false;
      try {
        expect(
          await runBackgroundSync(
            repositoryFactory: (lease) {
              created = true;
              return _WorkerRepository(lease);
            },
          ),
          isFalse,
        );
        expect(created, isFalse);
      } finally {
        foreground.release();
      }

      state.next = () async {};
    };
  };
  scenarios['1'] = (state) async {
    state.next = () async {
      late _WorkerRepository repository;
      state.next = () async {
        expect(
          await runBackgroundSync(
            repositoryFactory: (lease) =>
                repository = _WorkerRepository(lease)..linked = false,
          ),
          isTrue,
        );
        expect(repository.closed, isTrue);
        expect(repository.pulled, isFalse);
        state.next = () async {
          final lease = TaskStorageLease();
          state.next = () async {
            expect(await lease.acquire(wait: false), isTrue);
            lease.release();
          };
        };
      };
    };
  };
  scenarios['2'] = (state) async {
    state.next = () async {
      late _WorkerRepository repository;
      state.next = () async {
        expect(
          await runBackgroundSync(
            repositoryFactory: (lease) => repository = _WorkerRepository(lease)
              ..failure = const AccountException(
                AccountFailure.interactionRequired,
                'Reconnect',
              ),
          ),
          isTrue,
        );
        expect(repository.closed, isTrue);
      };
    };
  };

  scenarios['3'] = (state) async {
    state.next = () async {
      final fake = FakeRepo()..pendingPull = Completer<void>();
      final service = SyncService(fake);
      final first = service.sync();
      final second = service.sync();
      await Future<void>.delayed(Duration.zero);
      state.next = () async {
        expect(fake.pulls, 1);
        state.next = () async {
          fake.pendingPull!.complete();
          await Future.wait([first, second]);
          await service.sync();
          state.next = () async {
            expect(fake.pulls, 2);
            fake.dispose();
          };
        };
      };
    };
  };

  scenarios['4'] = (state) async {
    state.next = () async {
      final fake = FakeRepo()..pendingPull = Completer<void>();
      final service = SyncService(fake);
      final result = expectLater(service.sync(), throwsStateError);
      fake.pendingPull!.completeError(StateError('offline'));
      await result;
      fake.pendingPull = null;
      await service.sync();
      state.next = () async {
        expect(fake.pulls, 2);
        fake.dispose();
      };
    };
  };

  scenarios['5'] = (state) async {
    state.next = () async {
      final fake = FakeRepo()
        ..entries.addAll([
          CachedTask(
            id: null,
            tasklistId: 'list-1',
            localId: 'loc-1',
            title: 'New',
            dirty: true,
          ),
          CachedTask(
            id: 'srv-1',
            tasklistId: 'list-1',
            title: 'Edit',
            dirty: true,
          ),
          CachedTask(
            id: 'srv-2',
            tasklistId: 'list-1',
            title: 'Gone',
            isDeleted: true,
            dirty: true,
          ),
          CachedTask(
            id: 'srv-3',
            tasklistId: 'list-1',
            title: 'Clean',
            dirty: false,
          ),
        ]);

      final service = SyncService(fake);
      await service.sync();
      state.next = () async {
        expect(fake.pushedCreates, contains('loc-1'));
        expect(fake.pushedUpdates, contains('srv-1'));
        expect(fake.pushedDeletes, contains('srv-2'));
        expect(fake.pulled, isTrue);
      };
    };
  };

  scenarios['6'] = (state) async {
    state.next = () async {
      final fake = FakeRepo()
        ..entries.add(
          CachedTask(
            id: 'srv-1',
            tasklistId: 'list-1',
            title: 'Clean',
            dirty: false,
          ),
        );

      final service = SyncService(fake);
      await service.sync();
      state.next = () async {
        expect(fake.pushedCreates, isEmpty);
        expect(fake.pushedUpdates, isEmpty);
        expect(fake.pushedDeletes, isEmpty);
        expect(fake.pulled, isTrue);
      };
    };
  };

  scenarios['7'] = (state) async {
    state.next = () async {
      final fake = FakeRepo()..selectedId = null;
      final service = SyncService(fake);
      await service.sync();
      state.next = () async {
        expect(fake.pulled, isFalse);
        expect(fake.pushedCreates, isEmpty);
        expect(fake.pushedUpdates, isEmpty);
        expect(fake.pushedDeletes, isEmpty);
      };
    };
  };

  return scenarios;
}
