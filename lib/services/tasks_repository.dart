import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:googleapis/tasks/v1.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task_metadata.dart';
import '../utils/log.dart';
import 'auth_repository.dart';
import 'google_account_provider.dart';
import 'task_storage_lease.dart';
import 'widget_service.dart';

/// Parses a Google Tasks `updated` RFC-3339 string to milliseconds since the
/// epoch, or null when absent/unparsable.
int? _updatedMs(String? updated) =>
    updated == null ? null : DateTime.tryParse(updated)?.millisecondsSinceEpoch;

/// Hive box used for the offline task cache.
const String _kCacheBox = 'remindme_tasks_cache';

/// Prefix for the per-tasklist cache key.
String _cacheKey(String tasklistId) => 'tasks_$tasklistId';

/// A task entry persisted in the local Hive cache, augmented with sync state.
class CachedTask {
  CachedTask({
    required this.id,
    required this.tasklistId,
    this.localId,
    this.title,
    this.notes,
    this.status,
    this.due,
    this.completed = false,
    this.completedAt,
    this.parent,
    this.position,
    this.updatedAt,
    this.isDeleted = false,
    this.dirty = false,
  });

  /// Server-assigned task id (null for a locally-created task not yet pushed).
  final String? id;
  final String tasklistId;

  /// Stable client identity retained after upload for open offline editors.
  final String? localId;
  final String? title;
  final String? notes;
  final String? status;
  final String? due;
  final bool completed;
  final String? completedAt;
  final String? parent;
  final String? position;

  /// Last-write-wins timestamp (milliseconds since the epoch).
  final int? updatedAt;

  /// Soft-delete flag: deleted locally, awaiting remote removal.
  final bool isDeleted;

  /// True when a local change has not yet been pushed to the remote API.
  final bool dirty;

  CachedTask copyWith({
    String? id,
    String? localId,
    String? title,
    String? notes,
    String? status,
    String? due,
    bool? completed,
    String? completedAt,
    String? parent,
    String? position,
    int? updatedAt,
    bool? isDeleted,
    bool? dirty,
  }) {
    return CachedTask(
      id: id ?? this.id,
      tasklistId: tasklistId,
      localId: localId ?? this.localId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      due: due ?? this.due,
      completed: completed ?? this.completed,
      completedAt: completed != null && completed != this.completed
          ? completedAt
          : completedAt ?? this.completedAt,
      parent: parent ?? this.parent,
      position: position ?? this.position,
      updatedAt: updatedAt ?? this.updatedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      dirty: dirty ?? this.dirty,
    );
  }

  factory CachedTask.fromTask(Task task, String tasklistId) {
    return CachedTask(
      id: task.id,
      tasklistId: tasklistId,
      title: task.title,
      notes: task.notes,
      status: task.status,
      due: task.due,
      completed: task.status == 'completed',
      completedAt: task.completed,
      parent: task.parent,
      position: task.position,
      updatedAt: _updatedMs(task.updated),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'tasklistId': tasklistId,
    'localId': localId,
    'title': title,
    'notes': notes,
    'status': status,
    'due': due,
    'completed': completed,
    'completedAt': completedAt,
    'parent': parent,
    'position': position,
    'updatedAt': updatedAt,
    'isDeleted': isDeleted,
    'dirty': dirty,
  };

  factory CachedTask.fromJson(Map<String, dynamic> json) => CachedTask(
    id: json['id'] as String?,
    tasklistId: json['tasklistId'] as String? ?? '',
    localId: json['localId'] as String?,
    title: json['title'] as String?,
    notes: json['notes'] as String?,
    status: json['status'] as String?,
    due: json['due'] as String?,
    completed: json['completed'] as bool? ?? false,
    completedAt: json['completedAt'] as String?,
    parent: json['parent'] as String?,
    position: json['position'] as String?,
    updatedAt: json['updatedAt'] as int?,
    isDeleted: json['isDeleted'] as bool? ?? false,
    dirty: json['dirty'] as bool? ?? false,
  );

  /// Converts this cache entry to a Google [Task] for API calls / display.
  Task toTask() => Task(
    id: id ?? localId,
    title: title,
    notes: notes,
    status: status,
    completed: completed ? completedAt : null,
    due: due,
    parent: parent,
    position: position,
    updated: updatedAt == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(updatedAt!).toIso8601String(),
  );
}

/// Merges [remote] into [cached] using last-write-wins by [updatedAt].
///
/// A locally newer entry (including a locally-requested deletion) wins over an
/// older remote entry. A newer remote entry overwrites the local one and clears
/// the dirty flag. Entries present only locally (e.g. pending creates) are kept.
List<CachedTask> mergeTasks(
  List<CachedTask> cached,
  List<Task> remote, {
  required String tasklistId,
  int nowMs = 0,
}) {
  final effectiveNow = nowMs == 0
      ? DateTime.now().millisecondsSinceEpoch
      : nowMs;
  final byId = <String, CachedTask>{};
  for (final c in cached) {
    if (c.id != null) {
      byId[c.id!] = c;
    }
  }

  for (final r in remote) {
    final id = r.id;
    if (id == null) continue;
    final remoteMs = _updatedMs(r.updated) ?? effectiveNow;
    final existing = byId[id];
    if (existing == null) {
      byId[id] = CachedTask.fromTask(
        r,
        tasklistId,
      ).copyWith(updatedAt: remoteMs, isDeleted: false, dirty: false);
    } else if (remoteMs >= (existing.updatedAt ?? 0)) {
      // Remote wins (last-write-wins).
      var winner = CachedTask.fromTask(
        r,
        tasklistId,
      ).copyWith(updatedAt: remoteMs, dirty: false, localId: existing.localId);
      // Preserve a locally-requested deletion when it is newer than remote.
      if (existing.isDeleted && (existing.updatedAt ?? 0) > remoteMs) {
        winner = winner.copyWith(isDeleted: true);
      }
      byId[id] = winner;
    }
    // else: local entry is newer; keep it (may be dirty or deleted).
  }

  final operations = byId.values
      .map((e) => TaskMetadata.parse(e.notes).data['operationId'])
      .whereType<String>()
      .toSet();
  return [
    ...byId.values,
    ...cached.where(
      (e) =>
          e.id == null &&
          !operations.contains(TaskMetadata.parse(e.notes).data['operationId']),
    ),
  ];
}

class TasksRepository extends ChangeNotifier {
  TasksRepository({
    AuthRepository? authRepository,
    TaskStorageLease? storageLease,
  }) : _auth = authRepository ?? AuthRepository(),
       _ownsAuth = authRepository == null,
       _storageLease = storageLease ?? TaskStorageLease() {
    _auth.validateAccount = _validateAccount;
    _auth.addListener(_handleAuthChanged);
    _updateTasksApi();
  }

  final AuthRepository _auth;
  final bool _ownsAuth;
  final TaskStorageLease _storageLease;
  bool syncPending = false;
  bool get requiresReconnect => _auth.requiresReconnect;
  bool get hasLinkedAccount => signedIn;
  bool get changingAccount => _signingOut;
  http.Client? _apiClient;
  TasksApi? _tasksApi;
  Box? _cacheBox;
  bool initialized = false;
  String? initializationError;
  Future<void>? _initialization;
  Future<void>? _cacheInitialization;
  Future<void> Function(String tasklistId)? onRefreshTasks;
  List<TaskList> _taskLists = [];
  List<TaskList> get cachedTaskLists => List.unmodifiable(_taskLists);
  bool _disposed = false;
  bool _signingOut = false;

  // Forward authentication state to preserve the interface used by screens.
  bool get signedIn => _auth.signedIn;
  bool get signingIn => _signingOut || _auth.signingIn;
  set signingIn(bool value) => _auth.signingIn = value;
  String? get authError => _auth.authError;
  set authError(String? value) => _auth.authError = value;
  String? get userDisplayName => _auth.userDisplayName;
  String? get userEmail => _auth.userEmail;
  String? get userPhoto => _auth.userPhoto;
  Future<void> Function()? get onSignedIn => _auth.onSignedIn;
  set onSignedIn(Future<void> Function()? callback) =>
      _auth.onSignedIn = callback;

  void _updateTasksApi() {
    final client = _auth.client;
    if (!identical(client, _apiClient)) {
      _apiClient = client;
      _tasksApi = client == null ? null : TasksApi(client);
    }
  }

  void _handleAuthChanged() {
    if (_disposed) return;
    _updateTasksApi();
    notifyListeners();
  }

  Future<void> init() => _initialization ??= _initialize().whenComplete(() {
    _initialization = null;
  });

  Future<void> _initialize() async {
    initializationError = null;
    if (!_disposed) notifyListeners();
    try {
      await _storageLease.acquire();
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      _selectedTasklistId = prefs.getString(_kPrefKey);
      _showCompleted = prefs.getBool(_kShowCompletedPrefKey) ?? true;
      final savedLists = prefs.getString(_kTaskListsPrefKey);
      if (savedLists != null) {
        try {
          _taskLists = (jsonDecode(savedLists) as List)
              .map(
                (value) => TaskList.fromJson(Map<String, dynamic>.from(value)),
              )
              .toList();
        } catch (error, stack) {
          logError('Unable to read saved task lists', error, stack);
        }
      }
      await _auth.init();
      // Login has no use for the task box. Open it only for an authenticated
      // session; all task reads/writes also guard cache readiness.
      if (signedIn) {
        await _ensureCache();
        syncPending = _cacheBox!.values.any(
          (value) =>
              value is List &&
              value.any((entry) => entry is Map && entry['dirty'] == true),
        );
      }
      initialized = true;
    } catch (error, stack) {
      initializationError = 'Unable to initialize local data';
      logError('Unable to initialize repository', error, stack);
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> _ensureCache() {
    if (_cacheBox?.isOpen ?? false) return Future.value();
    return _cacheInitialization ??= _openCache().whenComplete(() {
      _cacheInitialization = null;
    });
  }

  Future<void> _openCache() async {
    await _storageLease.acquire();
    await Hive.initFlutter();
    _cacheBox = await Hive.openBox(_kCacheBox);
  }

  Future<void> signIn() async {
    if (!_signingOut) await _auth.signIn();
  }

  Future<void> requestAuthorization() => _auth.requestAuthorization();

  Future<void> _validateAccount(
    GoogleAccountAuthorization authorization,
  ) async {
    if (signedIn) return;
    await _ensureCache();
    if (_cacheBox!.isEmpty && _taskLists.isEmpty) return;
    final ids = <String>{
      ?_selectedTasklistId,
      ..._taskLists.map((list) => list.id).whereType<String>(),
      ..._cacheBox!.keys
          .whereType<String>()
          .where((key) => key.startsWith('tasks_'))
          .map((key) => key.substring(6)),
    };
    final client = http.Client();
    try {
      for (final id in ids) {
        final response = await client
            .get(
              Uri.https(
                'tasks.googleapis.com',
                '/tasks/v1/users/@me/lists/$id',
              ),
              headers: {'Authorization': 'Bearer ${authorization.accessToken}'},
            )
            .timeout(const Duration(seconds: 30));
        if (response.statusCode == 403 || response.statusCode == 404) {
          throw const AccountException(
            AccountFailure.mismatch,
            'Choose the account that owns your saved task list, or sign out to discard saved tasks.',
          );
        }
        if (response.statusCode != 200) {
          throw const AccountException(
            AccountFailure.temporary,
            'Unable to verify the account for your saved tasks. Please retry online.',
          );
        }
      }
    } finally {
      client.close();
    }
  }

  bool _defer(Object error) {
    final deferred =
        error is SocketException ||
        error is TimeoutException ||
        error is http.ClientException ||
        (error is AccountException &&
            (error.reason == AccountFailure.interactionRequired ||
                error.reason == AccountFailure.temporary));
    if (deferred) {
      syncPending = true;
      if (!_disposed) notifyListeners();
    }
    return deferred;
  }

  void markSynchronized() {
    syncPending = false;
    if (!_disposed) notifyListeners();
  }

  Future<void> signOut() async {
    if (_signingOut) return;
    _signingOut = true;
    notifyListeners();
    try {
      await _withTaskLock(() async {
        await _auth.signOut();
        await _ensureCache();
        await _cacheBox!.clear();
        _selectedTasklistId = null;
        _taskLists = [];
        syncPending = false;
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove(_kPrefKey);
        await prefs.remove(_kTaskListsPrefKey);
      }, changingAccount: true);
      await WidgetService.clearWidget();
    } finally {
      _signingOut = false;
      if (!_disposed) notifyListeners();
    }
  }

  // Keep cache read/modify/write operations and their API responses in order.
  Future<void> _taskWork = Future.value();

  Future<T> _withTaskLock<T>(
    Future<T> Function() action, {
    bool changingAccount = false,
  }) {
    if (_disposed || (_signingOut && !changingAccount)) {
      return Future.error(StateError('Sign out is in progress'));
    }
    final result = _taskWork.then((_) => action());
    _taskWork = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  static const _kTaskListsPrefKey = 'remindme_task_lists';
  static const _kPrefKey = 'remindme_tasklist_id';
  String? _selectedTasklistId;
  String? get selectedTasklistId => _selectedTasklistId;

  static const _kShowCompletedPrefKey = 'remindme_show_completed';
  bool _showCompleted = true;

  /// Whether completed tasks are listed on the app's task screen.
  ///
  /// The home-screen widget always shows outstanding items only, regardless of
  /// this setting.
  bool get showCompleted => _showCompleted;

  /// Shows or hides completed tasks on the app's task screen and persists the
  /// choice.
  Future<void> setShowCompleted(bool value) async {
    _showCompleted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowCompletedPrefKey, value);
    notifyListeners();
  }

  Future<void> selectTasklist(String id) async {
    _selectedTasklistId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPrefKey, id);
    notifyListeners();
  }

  Future<String> resolveDefaultTasklistId() async {
    final lists = await getTaskLists();
    if (lists.isEmpty) {
      final created = await _api(
        () => _tasksApi!.tasklists.insert(TaskList(title: 'Tasks')),
      );
      final id = created.id;
      if (id == null) throw StateError('Tasklist ID was null');
      return id;
    }
    final named = lists.firstWhere(
      (l) => l.title == 'Tasks',
      orElse: () => lists.first,
    );
    final id = named.id;
    if (id == null) throw StateError('Tasklist ID was null');
    return id;
  }

  Future<T> _api<T>(Future<T> Function() fn) async {
    if (_tasksApi == null) {
      throw const AccountException(
        AccountFailure.interactionRequired,
        'Please sign in again.',
      );
    }
    return fn().timeout(const Duration(seconds: 30));
  }

  Future<List<TaskList>> getTaskLists() async {
    final client = _apiClient;
    final lists = await _api(
      () => _tasksApi!.tasklists.list().then((v) => v.items ?? <TaskList>[]),
    );
    await _withTaskLock(() async {
      if (_disposed || _signingOut || !identical(client, _apiClient)) return;
      _taskLists = lists;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kTaskListsPrefKey,
        jsonEncode(lists.map((list) => list.toJson()).toList()),
      );
    });
    return lists;
  }

  /// Returns the saved snapshot, including a previously cached empty list.
  Future<List<Task>> getCachedTasks(String tasklistId) async =>
      (await _readCacheEntries(tasklistId))
          .where((entry) => !entry.isDeleted)
          .map((entry) => entry.toTask())
          .toList();

  Future<bool> hasCachedTasks(String tasklistId) async {
    await _ensureCache();
    return _cacheBox!.containsKey(_cacheKey(tasklistId));
  }

  /// Explicit refresh, coordinated with pending pushes by the app's SyncService.
  Future<void> refreshTasks(String tasklistId) =>
      onRefreshTasks?.call(tasklistId) ?? pullFromRemote(tasklistId);

  /// Reads a saved snapshot, populating it remotely only on the first read.
  /// Refreshing an existing snapshot is always explicit through [refreshTasks].
  Future<List<Task>> getTasks(String tasklistId) async {
    if (!await hasCachedTasks(tasklistId)) {
      try {
        await refreshTasks(tasklistId);
      } catch (error, stack) {
        logError('Unable to load initial tasks', error, stack);
      }
    }
    return getCachedTasks(tasklistId);
  }

  /// Pulls remote tasks for [tasklistId] and merges them into the local cache
  /// using last-write-wins (used by SyncService).
  Future<void> pullFromRemote(String tasklistId) =>
      _withTaskLock(() => _pullFromRemote(tasklistId));

  Future<void> _pullFromRemote(String tasklistId) async {
    final client = _apiClient;
    final remote = await _fetchRemoteTasks(tasklistId);
    if (_disposed || _signingOut || !identical(client, _apiClient)) return;
    final cached = await _readCacheEntries(tasklistId);
    final merged = mergeTasks(cached, remote, tasklistId: tasklistId);
    await _writeCacheEntries(tasklistId, merged);
    await _reconcileRecurrence(tasklistId);
  }

  Future<List<Task>> _fetchRemoteTasks(String tasklistId) => _api(() async {
    final allTasks = <Task>[];
    String? pageToken;
    do {
      final response = await _tasksApi!.tasks.list(
        tasklistId,
        showCompleted: true,
        showHidden: true,
        showDeleted: false,
        pageToken: pageToken,
        maxResults: 100,
        $fields:
            'nextPageToken,items(id,title,status,notes,due,completed,parent,position,updated)',
      );
      allTasks.addAll(response.items ?? []);
      pageToken = response.nextPageToken;
    } while (pageToken != null);
    return allTasks;
  });

  /// Reads the raw cache entries (including sync state) for [tasklistId].
  Future<List<CachedTask>> getCacheEntries(String tasklistId) =>
      _readCacheEntries(tasklistId);

  Future<List<CachedTask>> _readCacheEntries(String tasklistId) async {
    await _ensureCache();
    final raw = _cacheBox?.get(_cacheKey(tasklistId));
    if (raw == null) return <CachedTask>[];
    final list = List<Map<String, dynamic>>.from(
      (raw as List).map((e) => e.cast<String, dynamic>()),
    );
    return list.map((e) => CachedTask.fromJson(e)).toList();
  }

  Future<void> _writeCacheEntries(
    String tasklistId,
    List<CachedTask> entries,
  ) async {
    await _ensureCache();
    await _cacheBox!.put(
      _cacheKey(tasklistId),
      entries.map((e) => e.toJson()).toList(),
    );
    if (!_disposed) notifyListeners();
  }

  /// Persists [entries] to the local cache for [tasklistId] (used by SyncService).
  Future<void> saveCacheEntries(String tasklistId, List<CachedTask> entries) =>
      _writeCacheEntries(tasklistId, entries);

  Future<List<CachedTask>> _entries(String tasklistId) async =>
      _readCacheEntries(tasklistId);

  int _indexOf(List<CachedTask> entries, {String? serverId, String? localId}) {
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (serverId != null && (e.id == serverId || e.localId == serverId)) {
        return i;
      }
      if (localId != null && e.localId == localId) return i;
    }
    return -1;
  }

  Future<Task> createTask(
    String tasklistId, {
    required String title,
    String? notes,
    DateTime? due,
  }) => _withTaskLock(
    () => _createTask(tasklistId, title: title, notes: notes, due: due),
  );

  Future<Task> _createTask(
    String tasklistId, {
    required String title,
    String? notes,
    DateTime? due,
  }) async {
    final localId = 'local-${DateTime.now().microsecondsSinceEpoch}';
    final entry = CachedTask(
      id: null,
      tasklistId: tasklistId,
      localId: localId,
      title: title,
      notes: notes,
      status: 'needsAction',
      due: _formatDueDate(due),
      completed: false,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
      dirty: true,
    );
    final entries = await _entries(tasklistId)
      ..add(entry);
    await _writeCacheEntries(tasklistId, entries);
    notifyListeners();

    try {
      final created = await _api(
        () => _tasksApi!.tasks.insert(
          Task(title: title, notes: notes, due: _formatDueDate(due)),
          tasklistId,
        ),
      );
      final serverEntry = CachedTask.fromTask(created, tasklistId).copyWith(
        updatedAt:
            _updatedMs(created.updated) ??
            DateTime.now().millisecondsSinceEpoch,
        dirty: false,
        localId: localId,
        isDeleted: false,
      );
      final all = await _entries(tasklistId);
      final idx = _indexOf(all, localId: localId);
      if (idx != -1) all[idx] = serverEntry;
      await _writeCacheEntries(tasklistId, all);
      notifyListeners();
      return created;
    } catch (e) {
      // Entry stays dirty so a later sync can retry the remote create.
      if (_defer(e)) return entry.toTask();
      rethrow;
    }
  }

  /// Pushes a locally-created task to the remote API and folds the server
  /// result into the cache (used by SyncService). Does not re-add to cache.
  Future<void> pushCreate(String tasklistId, CachedTask entry) =>
      _withTaskLock(() => _pushCreate(tasklistId, entry));

  Future<void> _pushCreate(String tasklistId, CachedTask entry) async {
    final cached = await _entries(tasklistId);
    final index = _indexOf(cached, localId: entry.localId);
    if (index == -1 || cached[index].id != null || cached[index].isDeleted) {
      return;
    }
    entry = cached[index];
    final metadata = TaskMetadata.parse(entry.notes);
    final operation = metadata.data['operationId'];
    Task? existing;
    if (operation != null) {
      // A successor must not reach Google before its predecessor is completed.
      final predecessorId = metadata.data['previousOccurrenceId'];
      final predecessor = cached
          .where((e) => e.id == predecessorId)
          .firstOrNull;
      if (predecessor != null && !predecessor.isDeleted) {
        if (!predecessor.completed) return;
        if (predecessor.dirty) await _pushUpdate(tasklistId, predecessor);
      }
      final remote = await _fetchRemoteTasks(tasklistId);
      for (final task in remote) {
        if (TaskMetadata.parse(task.notes).data['operationId'] == operation) {
          existing = task;
          break;
        }
      }
    }
    final Task created =
        existing ??
        await _api<Task>(
          () => _tasksApi!.tasks.insert(
            Task(
              title: entry.title,
              notes: entry.notes,
              due: entry.due,
              status: entry.status,
            ),
            tasklistId,
            parent: entry.parent,
          ),
        );
    final serverEntry = CachedTask.fromTask(created, tasklistId).copyWith(
      updatedAt:
          _updatedMs(created.updated) ?? DateTime.now().millisecondsSinceEpoch,
      dirty: false,
      localId: entry.localId,
      isDeleted: false,
    );
    final all = await _entries(tasklistId);
    final idx = _indexOf(all, localId: entry.localId);
    if (idx != -1) {
      all.removeAt(idx);
      if (!all.any((e) => e.id == serverEntry.id)) all.add(serverEntry);
    }
    _recordSuccessor(all, serverEntry);
    await _writeCacheEntries(tasklistId, all);
    await _pushRecurrenceMarkers(tasklistId);
  }

  Future<Task> updateTask(
    String tasklistId,
    String taskId, {
    String? title,
    String? notes,
    bool? completed,
    DateTime? due,
  }) => _withTaskLock(
    () => _updateTask(
      tasklistId,
      taskId,
      title: title,
      notes: notes,
      completed: completed,
      due: due,
    ),
  );

  Future<Task> _updateTask(
    String tasklistId,
    String taskId, {
    String? title,
    String? notes,
    bool? completed,
    DateTime? due,
  }) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final entries = await _entries(tasklistId);
    final idx = _indexOf(entries, serverId: taskId);
    if (idx == -1) throw StateError('Task $taskId not in cache');
    final e = entries[idx];
    final newStatus = completed == null
        ? e.status
        : (completed ? 'completed' : 'needsAction');
    entries[idx] = CachedTask(
      id: e.id,
      tasklistId: e.tasklistId,
      localId: e.localId,
      title: title ?? e.title,
      notes: notes ?? e.notes,
      status: newStatus,
      due: due != null ? _formatDueDate(due) : e.due,
      completed: completed ?? e.completed,
      completedAt: completed == null || completed == e.completed
          ? e.completedAt
          : null,
      parent: e.parent,
      position: e.position,
      updatedAt: nowMs,
      isDeleted: e.isDeleted,
      dirty: true,
    );
    if (completed == true && !e.completed) _addNextOccurrences(entries);
    await _writeCacheEntries(tasklistId, entries);
    notifyListeners();

    if (e.id == null) {
      syncPending = true;
      return entries[idx].toTask();
    }
    try {
      final req = Task(
        title: title,
        notes: entries[idx].notes,
        status: newStatus,
        due: _formatDueDate(due),
      );
      final updated = await _api(
        () => _tasksApi!.tasks.patch(req, tasklistId, e.id!),
      );
      final serverEntry = CachedTask.fromTask(updated, tasklistId).copyWith(
        updatedAt: updated.updated == null
            ? nowMs
            : DateTime.tryParse(updated.updated!)?.millisecondsSinceEpoch ??
                  nowMs,
        dirty: false,
        localId: e.localId,
      );
      final all = await _entries(tasklistId);
      final sidx = _indexOf(all, serverId: taskId);
      if (sidx != -1) all[sidx] = serverEntry;
      await _writeCacheEntries(tasklistId, all);
      notifyListeners();
      await _pushOccurrences(tasklistId);
      return updated;
    } catch (error) {
      if (_defer(error)) return entries[idx].toTask();
      rethrow;
    }
  }

  /// Pushes a single local update to the remote API (used by SyncService).
  Future<void> pushUpdate(String tasklistId, CachedTask entry) =>
      _withTaskLock(() => _pushUpdate(tasklistId, entry));

  Future<void> _pushUpdate(String tasklistId, CachedTask entry) async {
    final cached = await _entries(tasklistId);
    final current = _indexOf(cached, serverId: entry.id);
    if (current == -1 || !cached[current].dirty || cached[current].isDeleted) {
      return;
    }
    entry = cached[current];
    final req = Task(
      title: entry.title,
      notes: entry.notes,
      status: entry.completed ? 'completed' : 'needsAction',
      completed: entry.completed ? entry.completedAt : null,
      due: entry.due,
    );
    final updated = await _api(
      () => _tasksApi!.tasks.patch(req, tasklistId, entry.id!),
    );
    final serverEntry = CachedTask.fromTask(updated, tasklistId).copyWith(
      updatedAt: updated.updated == null
          ? DateTime.now().millisecondsSinceEpoch
          : DateTime.tryParse(updated.updated!)?.millisecondsSinceEpoch ??
                DateTime.now().millisecondsSinceEpoch,
      dirty: false,
      localId: entry.localId,
    );
    final all = await _entries(tasklistId);
    final idx = _indexOf(all, serverId: entry.id!);
    if (idx != -1) all[idx] = serverEntry;
    await _writeCacheEntries(tasklistId, all);
    notifyListeners();
  }

  Future<void> deleteTask(String tasklistId, String taskId) =>
      _withTaskLock(() => _deleteTask(tasklistId, taskId));

  Future<void> _deleteTask(String tasklistId, String taskId) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final entries = await _entries(tasklistId);
    final idx = _indexOf(entries, serverId: taskId);
    if (idx != -1 && entries[idx].id == null) {
      entries.removeAt(idx);
      await _writeCacheEntries(tasklistId, entries);
      return;
    }
    if (idx == -1) {
      entries.add(
        CachedTask(
          id: taskId,
          tasklistId: tasklistId,
          updatedAt: nowMs,
          isDeleted: true,
          dirty: true,
        ),
      );
    } else {
      entries[idx] = entries[idx].copyWith(
        isDeleted: true,
        dirty: true,
        updatedAt: nowMs,
      );
    }
    await _writeCacheEntries(tasklistId, entries);
    notifyListeners();

    final serverId = idx == -1 ? taskId : entries[idx].id!;
    try {
      await _api(() => _tasksApi!.tasks.delete(tasklistId, serverId));
      final all = await _entries(tasklistId);
      all.removeWhere((e) => e.id == serverId);
      await _writeCacheEntries(tasklistId, all);
      notifyListeners();
    } catch (e) {
      // Tombstone stays dirty so a later sync can retry the remote delete.
      if (_defer(e)) return;
      rethrow;
    }
  }

  /// Pushes a single local deletion to the remote API (used by SyncService).
  Future<void> pushDelete(String tasklistId, CachedTask entry) =>
      _withTaskLock(() => _pushDelete(tasklistId, entry));

  Future<void> _pushDelete(String tasklistId, CachedTask entry) async {
    await _api(() => _tasksApi!.tasks.delete(tasklistId, entry.id!));
    final all = await _entries(tasklistId);
    all.removeWhere((e) => e.id == entry.id);
    await _writeCacheEntries(tasklistId, all);
    notifyListeners();
  }

  Future<void> completeTask(String tasklistId, String taskId, bool value) {
    return _withTaskLock(() async {
      final entries = await _entries(tasklistId);
      final index = _indexOf(entries, serverId: taskId);
      if (index == -1) throw StateError('Task $taskId not in cache');
      entries[index] = entries[index].copyWith(
        completed: value,
        status: value ? 'completed' : 'needsAction',
        dirty: true,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      _addNextOccurrences(entries);
      // One Hive write persists completion and its pending successor together.
      await _writeCacheEntries(tasklistId, entries);
      try {
        if (entries[index].id == null) {
          syncPending = true;
          return;
        }
        await _pushUpdate(tasklistId, entries[index]);
        await _pushOccurrences(tasklistId);
      } catch (error) {
        if (!_defer(error)) rethrow;
      }
    });
  }

  void _addNextOccurrences(List<CachedTask> entries) {
    for (final old in entries.toList()) {
      if (!old.completed || old.isDeleted || old.id == null) continue;
      final metadata = TaskMetadata.parse(old.notes);
      if (metadata.data['nextOccurrenceId'] != null) continue;
      final due = DateTime.tryParse(old.due ?? '');
      if (due == null) continue;
      final next = metadata.nextDue(due, DateTime.now());
      if (next == null) continue;
      final operation = 'repeat:${old.tasklistId}:${old.id}';
      if (entries.any(
        (e) => TaskMetadata.parse(e.notes).data['operationId'] == operation,
      )) {
        continue;
      }
      metadata.data['seriesId'] ??= '${old.tasklistId}:${old.id}';
      metadata.data['nextOperationId'] = operation;
      final oldIndex = _indexOf(entries, serverId: old.id);
      entries[oldIndex] = old.copyWith(
        notes: metadata.encode(),
        dirty: true,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      );
      metadata.data.remove('nextOperationId');
      metadata.data.remove('nextOccurrenceId');
      metadata.data['previousOccurrenceId'] = old.id;
      metadata.data['operationId'] = operation;
      entries.add(
        CachedTask(
          id: null,
          localId: operation,
          tasklistId: old.tasklistId,
          title: old.title,
          notes: metadata.encode(),
          due: _formatDueDate(next),
          status: 'needsAction',
          parent: old.parent,
          dirty: true,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }
  }

  Future<void> _pushOccurrences(String tasklistId) async {
    for (final entry in await _entries(tasklistId)) {
      if (entry.id == null &&
          TaskMetadata.parse(entry.notes).data['operationId'] != null) {
        await _pushCreate(tasklistId, entry);
      }
    }
  }

  Future<void> _reconcileRecurrence(String tasklistId) async {
    final entries = await _entries(tasklistId);
    for (final entry in entries.toList()) {
      if (entry.id != null) _recordSuccessor(entries, entry);
    }
    _addNextOccurrences(entries);
    await _writeCacheEntries(tasklistId, entries);
    await _pushRecurrenceMarkers(tasklistId);
    await _pushOccurrences(tasklistId);
  }

  void _recordSuccessor(List<CachedTask> entries, CachedTask successor) {
    final metadata = TaskMetadata.parse(successor.notes);
    final previous = metadata.data['previousOccurrenceId'];
    if (previous is! String || successor.id == null) return;
    final index = _indexOf(entries, serverId: previous);
    if (index == -1 || entries[index].isDeleted) return;
    final predecessor = entries[index];
    final oldMetadata = TaskMetadata.parse(predecessor.notes);
    if (oldMetadata.data['nextOccurrenceId'] != null) return;
    oldMetadata.data['seriesId'] ??= metadata.data['seriesId'];
    oldMetadata.data['nextOperationId'] ??=
        'repeat:${predecessor.tasklistId}:${predecessor.id}';
    oldMetadata.data['nextOccurrenceId'] = successor.id;
    entries[index] = predecessor.copyWith(
      notes: oldMetadata.encode(),
      dirty: true,
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> _pushRecurrenceMarkers(String tasklistId) async {
    for (final entry in await _entries(tasklistId)) {
      if (entry.id != null &&
          entry.dirty &&
          !entry.isDeleted &&
          TaskMetadata.parse(entry.notes).data['nextOperationId'] != null) {
        await _pushUpdate(tasklistId, entry);
      }
    }
  }

  Future<void> deleteCompletedTasks(
    String tasklistId, {
    void Function(int deleted, int total)? onProgress,
  }) async {
    final tasks = await getTasks(tasklistId);
    final completed = tasks
        .where((t) => t.status == 'completed' && t.id != null)
        .toList();
    var deleted = 0;
    onProgress?.call(deleted, completed.length);
    for (final task in completed) {
      await deleteTask(tasklistId, task.id!);
      onProgress?.call(++deleted, completed.length);
    }
    notifyListeners();
  }

  static String? _formatDueDate(DateTime? due) => due == null
      ? null
      : DateTime.utc(due.year, due.month, due.day).toIso8601String();

  Future<void> close() async {
    try {
      await _taskWork;
      await _cacheBox?.close();
    } finally {
      _cacheBox = null;
      _storageLease.release();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(close());
    _auth.removeListener(_handleAuthChanged);
    _auth.validateAccount = null;
    if (_ownsAuth) _auth.dispose();
    super.dispose();
  }
}
