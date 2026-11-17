import 'dart:async';

import 'package:flutter/material.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:home_widget/home_widget.dart';
import 'package:provider/provider.dart';

import '../screens/task_edit_screen.dart';
import '../services/tasks_repository.dart';
import '../utils/log.dart';

/// Owns widget launch subscriptions and defers navigation until auth is ready.
class WidgetTaskNavigator extends StatefulWidget {
  const WidgetTaskNavigator({
    super.key,
    required this.navigatorKey,
    required this.child,
  });

  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  @override
  State<WidgetTaskNavigator> createState() => _WidgetTaskNavigatorState();
}

class _WidgetTaskNavigatorState extends State<WidgetTaskNavigator> {
  StreamSubscription<Uri?>? _subscription;
  TasksRepository? _repository;
  Uri? _pending;
  Uri? _openingUri;
  Uri? _activeUri;
  Route<void>? _activeRoute;
  int _generation = 0;
  bool _opening = false;
  bool _scheduled = false;
  bool _receivedEvent = false;

  @override
  void initState() {
    super.initState();
    _subscription = HomeWidget.widgetClicked.listen(
      (uri) {
        _receivedEvent = true;
        _receive(uri ?? Uri.parse('remindme://home'));
      },
      onError: (Object error, StackTrace stack) {
        logError('Unable to receive widget clicks', error, stack);
      },
    );
    unawaited(_readInitialLaunch());
  }

  Future<void> _readInitialLaunch() async {
    try {
      final uri = await HomeWidget.initiallyLaunchedFromHomeWidget();
      if (mounted && !_receivedEvent && uri != null) _receive(uri);
    } catch (error, stack) {
      logError('Unable to read widget launch', error, stack);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final repository = context.read<TasksRepository>();
    if (!identical(_repository, repository)) {
      _repository?.removeListener(_schedule);
      _repository = repository;
      repository.addListener(_schedule);
    }
    _schedule();
  }

  void _receive(Uri uri) {
    if (!mounted) return;
    // Initial launch and stream delivery must not stack the same task screen.
    if ((_opening && _openingUri == uri) ||
        (_activeUri == uri && _activeRoute?.isCurrent == true)) {
      return;
    }
    _pending = uri;
    _generation++;
    _schedule();
  }

  void _schedule() {
    final repo = _repository;
    if (!mounted ||
        repo == null ||
        !repo.initialized ||
        !repo.signedIn ||
        _pending == null ||
        _opening ||
        _scheduled) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted) unawaited(_open());
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  bool _isCurrent(int generation) =>
      mounted &&
      generation == _generation &&
      _repository!.initialized &&
      _repository!.signedIn;

  Future<void> _open() async {
    final repo = _repository!;
    final uri = _pending;
    final navigator = widget.navigatorKey.currentState;
    if (uri == null ||
        navigator == null ||
        !repo.initialized ||
        !repo.signedIn) {
      return;
    }
    _pending = null;
    _opening = true;
    _openingUri = uri;
    final generation = _generation;
    navigator.popUntil((route) => route.isFirst);
    _activeRoute = null;
    _activeUri = null;
    try {
      final listId = uri.queryParameters['taskListId'];
      final taskId = uri.queryParameters['taskId'];
      if (uri.scheme != 'remindme' ||
          uri.host != 'task' ||
          uri.path != '/edit' ||
          listId == null ||
          listId.isEmpty ||
          taskId == null ||
          taskId.isEmpty) {
        return;
      }
      Task? findTask(List<Task> tasks) {
        for (final task in tasks) {
          if (task.id == taskId && task.deleted != true) return task;
        }
        return null;
      }

      var task = findTask(await repo.getCachedTasks(listId));
      if (!_isCurrent(generation)) return;
      if (task == null) {
        await repo.refreshTasks(listId);
        if (!_isCurrent(generation)) return;
        task = findTask(await repo.getCachedTasks(listId));
      }
      if (!_isCurrent(generation)) return;
      if (task == null) {
        _showUnavailable();
        return;
      }
      await repo.selectTasklist(listId);
      if (!_isCurrent(generation)) return;
      final selectedTask = task;
      final route = MaterialPageRoute<void>(
        builder: (_) => TaskEditScreen(taskListId: listId, task: selectedTask),
      );
      _activeUri = uri;
      _activeRoute = route;
      unawaited(navigator.push(route));
    } catch (error, stack) {
      logError('Unable to open widget task', error, stack);
      if (_isCurrent(generation)) _showUnavailable();
    } finally {
      _opening = false;
      _openingUri = null;
      _schedule();
    }
  }

  void _showUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'This task is unavailable. Refresh the task list and try again.',
        ),
      ),
    );
  }

  @override
  void dispose() {
    _generation++;
    _repository?.removeListener(_schedule);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
