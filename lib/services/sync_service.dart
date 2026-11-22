import 'dart:async';
import 'dart:ui';
import 'package:flutter/widgets.dart';

import 'package:workmanager/workmanager.dart';

import 'tasks_repository.dart';
import 'google_account_provider.dart';
import 'task_storage_lease.dart';
import 'widget_service.dart';
import '../utils/log.dart';

/// Name of the recurring background sync task.
const String _kSyncTask = 'remindme_sync';

@pragma('vm:entry-point')
void callbackDispatcher() {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != _kSyncTask) return true;
    return runBackgroundSync();
  });
}

Future<bool> runBackgroundSync({
  TaskStorageLease? storageLease,
  TasksRepository Function(TaskStorageLease lease)? repositoryFactory,
}) async {
  final lease = storageLease ?? TaskStorageLease();
  if (!await lease.acquire(wait: false)) return false;
  TasksRepository? repository;
  try {
    repository =
        repositoryFactory?.call(lease) ?? TasksRepository(storageLease: lease);
    await repository.init();
    if (!repository.initialized || repository.initializationError != null) {
      return false;
    }
    await repository.refreshReminders();
    if (!repository.hasLinkedAccount || repository.requiresReconnect) {
      return true;
    }
    final id = repository.selectedTasklistId;
    if (id == null) return true;
    await SyncService(repository).sync(tasklistId: id);
    final lists = repository.cachedTaskLists.where((list) => list.id == id);
    await WidgetService.updateWidget(
      await repository.getCachedTasks(id),
      taskListId: id,
      taskListName: lists.isEmpty ? 'Tasks' : lists.first.title,
    );
    return true;
  } on AccountException catch (error) {
    return error.reason == AccountFailure.interactionRequired ||
        error.reason == AccountFailure.mismatch;
  } catch (error, stack) {
    logError('Background sync deferred', error, stack);
    return false;
  } finally {
    try {
      await repository?.close();
    } finally {
      repository?.dispose();
      lease.release();
    }
  }
}

/// Orchestrates background sync between the local Hive cache and Google Tasks.
///
/// Pushes pending local changes to the remote API first, then pulls remote
/// changes into the cache using last-write-wins conflict resolution.
class SyncService {
  SyncService(this._repository);

  final TasksRepository _repository;
  final Map<String, Future<void>> _inFlight = {};

  /// Initializes workmanager and schedules the once-per-day periodic sync.
  ///
  /// Must be called after [WidgetsFlutterBinding.ensureInitialized].
  Future<void> init() async {
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _kSyncTask,
      _kSyncTask,
      frequency: const Duration(hours: 24),
      constraints: Constraints(networkType: NetworkType.connected),
    );
  }

  /// Performs a full push (local -> remote) then pull (remote -> local) sync
  /// for the currently selected tasklist.
  Future<void> sync({String? tasklistId}) async {
    final id = tasklistId ?? _repository.selectedTasklistId;
    if (id == null) return;
    await _runSync(tasklistId: id);
  }

  /// Sync triggered on sign-in: pushes pending local changes then pulls remote
  /// state. The UI can keep displaying its saved snapshot during this work.
  Future<void> syncOnSignIn() async {
    await sync();
  }

  Future<void> _runSync({String? tasklistId}) {
    final id = tasklistId ?? _repository.selectedTasklistId;
    if (id == null) return Future.value();
    return _inFlight.putIfAbsent(id, () {
      return _performSync(id).whenComplete(() {
        _inFlight.remove(id);
      });
    });
  }

  Future<void> _performSync(String id) async {
    // --- Push: local dirty changes -> remote ---
    final entries = await _repository.getCacheEntries(id);
    Object? pushError;
    for (final entry in entries) {
      if (!entry.dirty) continue;
      try {
        if (entry.id == null) {
          // Pending local create.
          await _repository.pushCreate(id, entry);
        } else if (entry.isDeleted) {
          await _repository.pushDelete(id, entry);
        } else {
          await _repository.pushUpdate(id, entry);
        }
      } catch (e, st) {
        if (e is AccountException &&
            (e.reason == AccountFailure.interactionRequired ||
                e.reason == AccountFailure.mismatch)) {
          rethrow;
        }
        pushError ??= e;
        logError('Failed to push ${entry.localId ?? entry.id}', e, st);
        // Entry stays dirty for the next sync attempt.
      }
    }

    // --- Pull: remote -> local (last-write-wins merge) ---
    await _repository.pullFromRemote(id);
    if (pushError != null) throw pushError;
    _repository.markSynchronized();
  }
}
