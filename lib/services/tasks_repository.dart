import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../utils/google_config.dart';
import '../utils/log.dart';
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
    this.parent,
    this.position,
    this.updatedAt,
    this.isDeleted = false,
    this.dirty = false,
  });

  /// Server-assigned task id (null for a locally-created task not yet pushed).
  final String? id;
  final String tasklistId;
  /// Client-generated id for a pending local create.
  final String? localId;
  final String? title;
  final String? notes;
  final String? status;
  final String? due;
  final bool completed;
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
    String? title,
    String? notes,
    String? status,
    String? due,
    bool? completed,
    String? parent,
    String? position,
    int? updatedAt,
    bool? isDeleted,
    bool? dirty,
  }) {
    return CachedTask(
      id: id ?? this.id,
      tasklistId: tasklistId,
      localId: localId,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      status: status ?? this.status,
      due: due ?? this.due,
      completed: completed ?? this.completed,
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
        parent: json['parent'] as String?,
        position: json['position'] as String?,
        updatedAt: json['updatedAt'] as int?,
        isDeleted: json['isDeleted'] as bool? ?? false,
        dirty: json['dirty'] as bool? ?? false,
      );

  /// Converts this cache entry to a Google [Task] for API calls / display.
  Task toTask() => Task(
        id: id,
        title: title,
        notes: notes,
        status: status,
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
  final effectiveNow = nowMs == 0 ? DateTime.now().millisecondsSinceEpoch : nowMs;
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
      byId[id] = CachedTask.fromTask(r, tasklistId).copyWith(
        updatedAt: remoteMs,
        isDeleted: false,
        dirty: false,
      );
    } else if (remoteMs >= (existing.updatedAt ?? 0)) {
      // Remote wins (last-write-wins).
      var winner = CachedTask.fromTask(r, tasklistId).copyWith(
        updatedAt: remoteMs,
        dirty: false,
      );
      // Preserve a locally-requested deletion when it is newer than remote.
      if (existing.isDeleted && (existing.updatedAt ?? 0) > remoteMs) {
        winner = winner.copyWith(isDeleted: true);
      }
      byId[id] = winner;
    }
    // else: local entry is newer; keep it (may be dirty or deleted).
  }

  return byId.values.toList();
}

class TasksRepository extends ChangeNotifier {
  final GoogleSignIn _signIn = GoogleSignIn.instance;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;
  GoogleSignInAccount? _currentUser;
  GoogleSignInClientAuthorization? _authorization;
  TasksApi? _tasksApi;
  Box? _cacheBox;
  bool initialized = false;

  /// Fired after a successful sign-in once authorization is established.
  Future<void> Function()? onSignedIn;

  bool get signedIn =>
      _currentUser != null && _authorization != null && _tasksApi != null;

  String? get userDisplayName => _currentUser?.displayName;
  String? get userEmail => _currentUser?.email;
  String? get userPhoto => _currentUser?.photoUrl;

  TasksRepository();

  bool signingIn = false;
  String? authError;
  bool _googleInitialized = false;
  bool _disposed = false;
  int _authGeneration = 0;

  void _publishAuth() {
    if (!_disposed) notifyListeners();
  }

  void _clearAuthentication() {
    _authGeneration++;
    _currentUser = null;
    _authorization = null;
    _tasksApi = null;
    signingIn = false;
  }

  void _authenticationFailed(Object error, StackTrace stack) {
    logError('Sign in failed', error, stack);
    _clearAuthentication();
    authError =
        error is GoogleSignInException &&
            error.code == GoogleSignInExceptionCode.canceled
        ? null
        : 'Unable to sign in. Please try again.';
    _publishAuth();
  }

  Future<void> _initializeGoogle() async {
    if (_googleInitialized) return;
    await _signIn.initialize(
      serverClientId: getGoogleWebClientId().isNotEmpty
          ? getGoogleWebClientId()
          : null,
    );
    _googleInitialized = true;
    _sub = _signIn.authenticationEvents.listen(
      (event) {
        if (event is GoogleSignInAuthenticationEventSignOut) {
          _clearAuthentication();
          _publishAuth();
        } else if (event is GoogleSignInAuthenticationEventSignIn &&
            !signingIn) {
          unawaited(_acceptEvent(event.user));
        }
      },
      onError: (Object error, StackTrace stack) {
        _authenticationFailed(error, stack);
      },
    );
  }

  Future<void> _acceptEvent(GoogleSignInAccount user) async {
    signingIn = true;
    final generation = ++_authGeneration;
    try {
      await _completeSignIn(user, generation);
    } catch (error, stack) {
      if (generation == _authGeneration) _authenticationFailed(error, stack);
    } finally {
      if (generation == _authGeneration) {
        signingIn = false;
        _publishAuth();
      }
    }
  }

  Future<void> init() async {
    await Hive.initFlutter();
    _cacheBox = await Hive.openBox(_kCacheBox);

    await _loadSelectedTasklist();
    await _loadShowCompleted();
    signingIn = true;
    final generation = ++_authGeneration;
    try {
      await _initializeGoogle();
      final account = await _signIn.attemptLightweightAuthentication();
      if (account != null) await _completeSignIn(account, generation);
    } catch (error, stack) {
      _authenticationFailed(error, stack);
    } finally {
      signingIn = false;
      initialized = true;
      _publishAuth();
    }
  }

  Future<void> signIn() async {
    if (signingIn) return;
    signingIn = true;
    authError = null;
    final generation = ++_authGeneration;
    _publishAuth();
    try {
      await _initializeGoogle();
      final user = await _signIn.authenticate();
      await _completeSignIn(user, generation);
    } catch (error, stack) {
      if (generation == _authGeneration) _authenticationFailed(error, stack);
    } finally {
      if (generation == _authGeneration) {
        signingIn = false;
        _publishAuth();
      }
    }
  }

  Future<void> signOut() async {
    _clearAuthentication();
    authError = null;
    _publishAuth();
    try {
      await _signIn.disconnect();
    } finally {
      await WidgetService.clearWidget();
    }
  }

  Future<void> _completeSignIn(GoogleSignInAccount user, int generation) async {
    final client = user.authorizationClient;
    final authorization =
        await client.authorizationForScopes(googleTasksScopes) ??
        await client.authorizeScopes(googleTasksScopes);
    if (_disposed || generation != _authGeneration) return;
    _currentUser = user;
    _authorization = authorization;
    _tasksApi = _buildClient(authorization);
    authError = null;
    _publishAuth();
    try {
      await onSignedIn?.call();
    } catch (error, stack) {
      logError('Initial task sync failed', error, stack);
    }
  }

  Future<void> requestAuthorization() async {
    final user = _currentUser;
    if (user != null) await _acceptEvent(user);
  }

  TasksApi _buildClient(GoogleSignInClientAuthorization authz) {
    final client = authz.authClient(scopes: googleTasksScopes);
    return TasksApi(client);
  }

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

  Future<void> _loadShowCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    _showCompleted = prefs.getBool(_kShowCompletedPrefKey) ?? true;
  }

  /// Shows or hides completed tasks on the app's task screen and persists the
  /// choice.
  Future<void> setShowCompleted(bool value) async {
    _showCompleted = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kShowCompletedPrefKey, value);
    notifyListeners();
  }

  Future<void> _loadSelectedTasklist() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedTasklistId = prefs.getString(_kPrefKey);
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
      final created = await _tasksApi!.tasklists.insert(TaskList(title: 'Tasks'));
      final id = created.id;
      if (id == null) throw StateError('Tasklist ID was null');
      return id;
    }
    final named = lists.firstWhere((l) => l.title == 'Tasks', orElse: () => lists.first);
    final id = named.id;
    if (id == null) throw StateError('Tasklist ID was null');
    return id;
  }

  Future<T> _api<T>(Future<T> Function() fn) async {
    try {
      return await fn();
    } on DetailedApiRequestError catch (e) {
      if (e.status == 401) {
        _clearAuthentication();
        authError = 'Your session expired. Please sign in again.';
        _publishAuth();
      }
      rethrow;
    }
  }

  Future<List<TaskList>> getTaskLists() =>
      _api(() => _tasksApi!.tasklists.list().then((v) => v.items ?? []));

  /// Reads tasks for [tasklistId] from the local cache only (never the network).
  ///
  /// When the cache is empty (cold start) it is populated from the remote API.
  /// On a warm cache the local copy is returned immediately and a background
  /// refresh is scheduled so subsequent reads stay fresh.
  Future<List<Task>> getTasks(String tasklistId) async {
    final cached = await _readCacheEntries(tasklistId).then((entries) =>
        entries.where((e) => !e.isDeleted).map((e) => e.toTask()).toList());

    if (cached.isEmpty) {
      try {
        final remote = await _fetchRemoteTasks(tasklistId);
        await _writeCacheEntries(tasklistId, _toCached(remote, tasklistId));
        return remote;
      } catch (_) {
        return <Task>[];
      }
    }

    // ignore: unawaited_futures
    _syncTaskList(tasklistId);
    return cached;
  }

  /// Pulls remote tasks for [tasklistId] and merges them into the local cache
  /// using last-write-wins (used by SyncService).
  Future<void> pullFromRemote(String tasklistId) async {
    final remote = await _fetchRemoteTasks(tasklistId);
    final cached = await _readCacheEntries(tasklistId);
    final merged = mergeTasks(cached, remote, tasklistId: tasklistId);
    await _writeCacheEntries(tasklistId, merged);
  }

  /// Pulls remote tasks for [tasklistId] and merges them into the local cache
  /// using last-write-wins. Swallows errors so background sync never crashes.
  Future<void> _syncTaskList(String tasklistId) async {
    try {
      await pullFromRemote(tasklistId);
    } catch (e, st) {
      logError('Background task sync failed', e, st);
    }
  }

  Future<List<Task>> _fetchRemoteTasks(String tasklistId) => _api(() async {
        final allTasks = <Task>[];
        String? pageToken;
        do {
          final response = await _tasksApi!.tasks.list(
            tasklistId,
            showCompleted: true,
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

  List<CachedTask> _toCached(List<Task> tasks, String tasklistId) =>
      tasks.map((t) => CachedTask.fromTask(t, tasklistId)).toList();

  /// Reads the raw cache entries (including sync state) for [tasklistId].
  Future<List<CachedTask>> getCacheEntries(String tasklistId) =>
      _readCacheEntries(tasklistId);

  Future<List<CachedTask>> _readCacheEntries(String tasklistId) async {
    final raw = _cacheBox?.get(_cacheKey(tasklistId));
    if (raw == null) return <CachedTask>[];
    final list = List<Map<String, dynamic>>.from(
      (raw as List).map((e) => e.cast<String, dynamic>()),
    );
    return list.map((e) => CachedTask.fromJson(e)).toList();
  }

  Future<void> _writeCacheEntries(String tasklistId, List<CachedTask> entries) async {
    await _cacheBox?.put(
        _cacheKey(tasklistId), entries.map((e) => e.toJson()).toList());
    notifyListeners();
  }

  /// Persists [entries] to the local cache for [tasklistId] (used by SyncService).
  Future<void> saveCacheEntries(String tasklistId, List<CachedTask> entries) =>
      _writeCacheEntries(tasklistId, entries);

  Future<List<CachedTask>> _entries(String tasklistId) async =>
      _readCacheEntries(tasklistId);

  int _indexOf(List<CachedTask> entries, {String? serverId, String? localId}) {
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      if (serverId != null && e.id == serverId) return i;
      if (localId != null && e.localId == localId) return i;
    }
    return -1;
  }

  Future<Task> createTask(
    String tasklistId, {
    required String title,
    String? notes,
    DateTime? due,
  }) async {
    final localId = 'local-${DateTime.now().millisecondsSinceEpoch}';
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
      final entries = await _entries(tasklistId)..add(entry);
      await _writeCacheEntries(tasklistId, entries);
      notifyListeners();

      try {
        final created = await _api(() => _tasksApi!.tasks.insert(
              Task(title: title, notes: notes, due: _formatDueDate(due)),
              tasklistId,
            ));
        final serverEntry = CachedTask.fromTask(created, tasklistId).copyWith(
          updatedAt:
              _updatedMs(created.updated) ?? DateTime.now().millisecondsSinceEpoch,
          dirty: false,
          isDeleted: false,
        );
        final all = await _entries(tasklistId);
        final idx = _indexOf(all, localId: localId);
        if (idx != -1) all[idx] = serverEntry;
      await _writeCacheEntries(tasklistId, all);
      notifyListeners();
      return created;
    } catch (e) {
      // Entry stays dirty so background sync can retry the remote create.
      rethrow;
    }
  }

  /// Pushes a locally-created task to the remote API and folds the server
  /// result into the cache (used by SyncService). Does not re-add to cache.
  Future<void> pushCreate(String tasklistId, CachedTask entry) async {
    final created = await _api(() => _tasksApi!.tasks.insert(
          Task(
            title: entry.title,
            notes: entry.notes,
            due: entry.due,
          ),
          tasklistId,
        ));
    final serverEntry = CachedTask.fromTask(created, tasklistId).copyWith(
      updatedAt: _updatedMs(created.updated) ??
          DateTime.now().millisecondsSinceEpoch,
      dirty: false,
      isDeleted: false,
    );
    final all = await _entries(tasklistId);
    final idx = _indexOf(all, localId: entry.localId);
    if (idx != -1) all[idx] = serverEntry;
    await _writeCacheEntries(tasklistId, all);
    notifyListeners();
  }

  Future<Task> updateTask(
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
    final newStatus =
        completed == null ? e.status : (completed ? 'completed' : 'needsAction');
    entries[idx] = CachedTask(
      id: e.id,
      tasklistId: e.tasklistId,
      localId: e.localId,
      title: title ?? e.title,
      notes: notes ?? e.notes,
      status: newStatus,
      due: due != null ? _formatDueDate(due) : e.due,
      completed: completed ?? e.completed,
      parent: e.parent,
      position: e.position,
      updatedAt: nowMs,
      isDeleted: e.isDeleted,
      dirty: true,
    );
    await _writeCacheEntries(tasklistId, entries);
    notifyListeners();

    try {
      final req = Task(
        title: title,
        notes: notes,
        status: newStatus,
        due: _formatDueDate(due),
      );
      final updated = await _api(() => _tasksApi!.tasks.patch(req, tasklistId, taskId));
      final serverEntry = CachedTask.fromTask(updated, tasklistId).copyWith(
        updatedAt: updated.updated == null
            ? nowMs
            : DateTime.tryParse(updated.updated!)?.millisecondsSinceEpoch ??
                nowMs,
        dirty: false,
      );
      final all = await _entries(tasklistId);
      final sidx = _indexOf(all, serverId: taskId);
      if (sidx != -1) all[sidx] = serverEntry;
      await _writeCacheEntries(tasklistId, all);
      notifyListeners();
      return updated;
    } catch (e) {
      rethrow;
    }
  }

  /// Pushes a single local update to the remote API (used by SyncService).
  Future<void> pushUpdate(String tasklistId, CachedTask entry) async {
    final req = Task(
      title: entry.title,
      notes: entry.notes,
      status: entry.completed ? 'completed' : 'needsAction',
      due: entry.due,
    );
    final updated = await _api(() => _tasksApi!.tasks.patch(req, tasklistId, entry.id!));
    final serverEntry = CachedTask.fromTask(updated, tasklistId).copyWith(
      updatedAt: updated.updated == null
          ? DateTime.now().millisecondsSinceEpoch
          : DateTime.tryParse(updated.updated!)?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch,
      dirty: false,
    );
    final all = await _entries(tasklistId);
    final idx = _indexOf(all, serverId: entry.id!);
    if (idx != -1) all[idx] = serverEntry;
    await _writeCacheEntries(tasklistId, all);
    notifyListeners();
  }

  Future<void> deleteTask(String tasklistId, String taskId) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final entries = await _entries(tasklistId);
    final idx = _indexOf(entries, serverId: taskId);
    if (idx == -1) {
      entries.add(CachedTask(
        id: taskId,
        tasklistId: tasklistId,
        updatedAt: nowMs,
        isDeleted: true,
        dirty: true,
      ));
    } else {
      entries[idx] = entries[idx].copyWith(
        isDeleted: true,
        dirty: true,
        updatedAt: nowMs,
      );
    }
    await _writeCacheEntries(tasklistId, entries);
    notifyListeners();

    try {
      await _api(() => _tasksApi!.tasks.delete(tasklistId, taskId));
      final all = await _entries(tasklistId);
      all.removeWhere((e) => e.id == taskId);
      await _writeCacheEntries(tasklistId, all);
      notifyListeners();
    } catch (e) {
      // Tombstone stays dirty so background sync can retry the remote delete.
      rethrow;
    }
  }

  /// Pushes a single local deletion to the remote API (used by SyncService).
  Future<void> pushDelete(String tasklistId, CachedTask entry) async {
    await _api(() => _tasksApi!.tasks.delete(tasklistId, entry.id!));
    final all = await _entries(tasklistId);
    all.removeWhere((e) => e.id == entry.id);
    await _writeCacheEntries(tasklistId, all);
    notifyListeners();
  }

  Future<void> completeTask(String tasklistId, String taskId, bool value) =>
      updateTask(tasklistId, taskId, completed: value);

  Future<void> deleteCompletedTasks(String tasklistId) async {
    final tasks = await getTasks(tasklistId);
    final completed = tasks.where((t) => t.status == 'completed' && t.id != null);
    for (final task in completed) {
      await deleteTask(tasklistId, task.id!);
    }
    notifyListeners();
  }

  static String? _formatDueDate(DateTime? due) =>
      due == null ? null : DateTime.utc(due.year, due.month, due.day).toIso8601String();

  @override
  void dispose() {
    _disposed = true;
    _authGeneration++;
    _sub?.cancel();
    super.dispose();
  }
}
