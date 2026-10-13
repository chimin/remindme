import 'dart:async';
import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../utils/google_config.dart';

class TasksRepository extends ChangeNotifier {
  final GoogleSignIn _signIn = GoogleSignIn.instance;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;
  GoogleSignInAccount? _currentUser;
  GoogleSignInClientAuthorization? _authorization;
  TasksApi? _tasksApi;
  bool initialized = false;

  bool get signedIn =>
      _currentUser != null && _authorization != null && _tasksApi != null;

  String? get userDisplayName => _currentUser?.displayName;
  String? get userEmail => _currentUser?.email;
  String? get userPhoto => _currentUser?.photoUrl;

  TasksRepository();

  Future<void> init() async {
    await _signIn.initialize(serverClientId: getGoogleWebClientId().isNotEmpty ? getGoogleWebClientId() : null);
    initialized = true;
    _sub = _signIn.authenticationEvents.listen((e) async {
      switch (e) {
        case GoogleSignInAuthenticationEventSignIn():
          _currentUser = e.user;
          await _checkAuthorization();
          break;
        case GoogleSignInAuthenticationEventSignOut():
          _currentUser = null;
          _authorization = null;
          _tasksApi = null;
          break;
      }
      notifyListeners();
    });
    unawaited(_signIn.attemptLightweightAuthentication());
    await _loadSelectedTasklist();
  }

  Future<void> signIn() => _signIn.authenticate();

  Future<void> signOut() => _signIn.disconnect();

  Future<void> _checkAuthorization() async {
    final authz = await _currentUser?.authorizationClient
        .authorizationForScopes(googleTasksScopes);
    _authorization = authz;
    if (authz != null) {
      _tasksApi = _buildClient(authz);
    } else {
      // Fallback: request authorization if not already granted
      await requestAuthorization();
      return;
    }
    notifyListeners();
  }

  Future<void> requestAuthorization() async {
    final client = _currentUser?.authorizationClient;
    if (client == null) return;
    final authz = await client.authorizeScopes(googleTasksScopes);
    _authorization = authz;
    if (_authorization != null) {
      _tasksApi = _buildClient(_authorization!);
    }
    notifyListeners();
  }

  TasksApi _buildClient(GoogleSignInClientAuthorization authz) {
    final client = authz.authClient(scopes: googleTasksScopes);
    return TasksApi(client);
  }

  static const _kPrefKey = 'remindme_tasklist_id';
  String? _selectedTasklistId;
  String? get selectedTasklistId => _selectedTasklistId;

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
        await signOut();
        await signIn();
        return await fn();
      }
      rethrow;
    }
  }

  Future<List<TaskList>> getTaskLists() =>
      _api(() => _tasksApi!.tasklists.list().then((v) => v.items ?? []));

  Future<List<Task>> getTasks(String tasklistId) => _api(() async {
      final allTasks = <Task>[];
      String? pageToken;
      do {
        final response = await _tasksApi!.tasks.list(
          tasklistId,
          showCompleted: true,
          showDeleted: false,
          pageToken: pageToken,
          maxResults: 100,
          $fields: 'nextPageToken,items(id,title,status,notes,due,completed,parent,position)',
        );
        allTasks.addAll(response.items ?? []);
        pageToken = response.nextPageToken;
      } while (pageToken != null);
      return allTasks;
    });

  Future<Task> createTask(
    String tasklistId, {
    required String title,
    String? notes,
    DateTime? due,
  }) async =>
      _api(() => _tasksApi!.tasks.insert(
            Task(title: title, notes: notes, due: due?.toIso8601String()),
            tasklistId,
          ));

  Future<Task> updateTask(
    String tasklistId,
    String taskId, {
    String? title,
    String? notes,
    bool? completed,
  }) async {
    final req = Task(
      title: title,
      notes: notes,
      status: (completed == true) ? 'completed' : 'needsAction',
    );
    return _api(() => _tasksApi!.tasks.patch(req, tasklistId, taskId));
  }

  Future<void> deleteTask(String tasklistId, String taskId) =>
      _api(() => _tasksApi!.tasks.delete(tasklistId, taskId));

  Future<void> completeTask(String tasklistId, String taskId, bool value) =>
      _api(() => _tasksApi!.tasks.patch(
            Task(status: value ? 'completed' : 'needsAction'),
            tasklistId,
            taskId,
          ));

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
