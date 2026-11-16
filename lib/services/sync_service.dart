import 'dart:async';

import 'package:workmanager/workmanager.dart';

import 'tasks_repository.dart';
import '../utils/log.dart';

/// Name of the recurring background sync task.
const String _kSyncTask = 'remindme_sync';

/// The SyncService instance used by the top-level [callbackDispatcher].
SyncService? _syncServiceInstance;

/// Top-level entry point invoked by the workmanager plugin on Android/iOS
/// whenever a scheduled background task is due.
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    switch (taskName) {
      case _kSyncTask:
        await _syncServiceInstance?._runSync();
        break;
    }
    return Future.value(true);
  });
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
    _syncServiceInstance = this;
    await Workmanager().initialize(callbackDispatcher);
    await Workmanager().registerPeriodicTask(
      _kSyncTask,
      _kSyncTask,
      frequency: const Duration(hours: 24),
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
        logError('Failed to push ${entry.localId ?? entry.id}', e, st);
        // Entry stays dirty for the next sync attempt.
      }
    }

    // --- Pull: remote -> local (last-write-wins merge) ---
    await _repository.pullFromRemote(id);
  }
}
