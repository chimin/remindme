import 'package:flutter_test/flutter_test.dart';

import 'package:remindme/services/sync_service.dart';
import 'package:remindme/services/tasks_repository.dart';

class FakeRepo extends TasksRepository {
  String? selectedId = 'list-1';
  final List<CachedTask> entries = <CachedTask>[];
  final List<String> pushedCreates = <String>[];
  final List<String> pushedUpdates = <String>[];
  final List<String> pushedDeletes = <String>[];
  bool pulled = false;

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
  }
}

void main() {
  test(
    'sync should push dirty local changes to remote then pull remote when a tasklist is selected',
    () async {
      final fake = FakeRepo()
        ..entries.addAll([
          CachedTask(
            id: null, tasklistId: 'list-1', localId: 'loc-1',
            title: 'New', dirty: true,
          ),
          CachedTask(
            id: 'srv-1', tasklistId: 'list-1', title: 'Edit',
            dirty: true,
          ),
          CachedTask(
            id: 'srv-2', tasklistId: 'list-1', title: 'Gone',
            isDeleted: true, dirty: true,
          ),
          CachedTask(
            id: 'srv-3', tasklistId: 'list-1', title: 'Clean',
            dirty: false,
          ),
        ]);

      final service = SyncService(fake);
      await service.sync();

      expect(fake.pushedCreates, contains('loc-1'));
      expect(fake.pushedUpdates, contains('srv-1'));
      expect(fake.pushedDeletes, contains('srv-2'));
      expect(fake.pulled, isTrue);
    },
  );

  test(
    'sync should skip entries that are not dirty',
    () async {
      final fake = FakeRepo()
        ..entries.add(
          CachedTask(id: 'srv-1', tasklistId: 'list-1', title: 'Clean', dirty: false),
        );

      final service = SyncService(fake);
      await service.sync();

      expect(fake.pushedCreates, isEmpty);
      expect(fake.pushedUpdates, isEmpty);
      expect(fake.pushedDeletes, isEmpty);
      expect(fake.pulled, isTrue);
    },
  );

  test(
    'sync should do nothing when no tasklist is selected',
    () async {
      final fake = FakeRepo()..selectedId = null;
      final service = SyncService(fake);
      await service.sync();

      expect(fake.pulled, isFalse);
      expect(fake.pushedCreates, isEmpty);
      expect(fake.pushedUpdates, isEmpty);
      expect(fake.pushedDeletes, isEmpty);
    },
  );
}
