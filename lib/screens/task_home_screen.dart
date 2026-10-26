import 'package:flutter/material.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:provider/provider.dart';

import '../models/task_item.dart';
import '../models/task_metadata.dart';
import '../services/tasks_repository.dart';
import '../services/widget_color_service.dart';
import '../services/widget_service.dart';
import '../utils/log.dart';
import '../utils/task_grouping.dart';
import '../widgets/trailing_checked_menu_item.dart';
import 'task_edit_screen.dart';
import 'widget_color_config_dialog.dart';

/// Actions available from the app bar overflow menu.
enum _AppBarAction { toggleCompleted, widgetColors, deleteCompleted, signOut }

/// Vertical nudge applied to the overflow menu so its top edge lines up with
/// the top edge of the task list menu.
///
/// The overflow button is a 48px icon button whose icon is centred in the
/// toolbar, while the title button only wraps the title line, so anchoring
/// both menus with [PopupMenuPosition.under] leaves them 2px apart.
const double _kOverflowMenuOffset = -2;

/// Home screen listing the tasks of the selected Google task list.
///
/// The app bar exposes two Material popup menus that share the same styling:
/// the title acts as a task list switcher (a [PopupMenuButton] with a
/// dropdown indicator) and the overflow button holds the app wide actions.
/// Both menus render their entries as [TrailingCheckedMenuItem]s so the active
/// choice is marked with a checkmark on the right.
///
/// Only one popup can be visible at a time because every Material popup menu
/// is pushed as a modal route whose barrier swallows taps aimed at the
/// underlying screen.
class TaskHomeScreen extends StatefulWidget {
  const TaskHomeScreen({super.key});

  @override
  State<TaskHomeScreen> createState() => _TaskHomeScreenState();
}

class _TaskHomeScreenState extends State<TaskHomeScreen> {
  bool _loading = false;
  List<TaskList> _taskLists = [];
  List<Task> _tasks = [];

  TasksRepository _getRepo() => context.read<TasksRepository>();
  String? _getSelectedId() => _getRepo().selectedTasklistId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  List<TaskGroup> _groupTasks({required bool showCompleted}) =>
      groupTasksByDueDate(_tasks, DateTime.now(), showCompleted: showCompleted);

  /// Title of the currently selected task list, used as the widget title.
  ///
  /// Returns `null` when the selected list is unknown (e.g. its name has not
  /// been loaded yet), in which case the widget shows no title.
  String? _selectedTaskListTitle() {
    final selectedId = _getSelectedId();
    if (selectedId == null) return null;
    for (final list in _taskLists) {
      if (list.id == selectedId) return list.title;
    }
    return null;
  }

  Widget _buildGroupedTaskList({required List<TaskGroup> groups}) {
    final selectedId = _getSelectedId();

    return ListView(
      children: groups.expand((group) {
        final tasks = group.tasks;
        final isPast = group.category == 'overdue';

        return [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              group.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isPast ? Colors.red : null,
              ),
            ),
          ),
          ...tasks.map((task) {
            final completed = task.status == 'completed';
            final metadata = TaskMetadata.parse(task.notes);
            return Dismissible(
              key: Key(task.id ?? 'task-${task.title.hashCode}'),
              direction: DismissDirection.endToStart,
              confirmDismiss: (_) async => task.id != null,
              onDismissed: (_) async {
                if (task.id == null || selectedId == null) return;
                await _getRepo().deleteTask(selectedId, task.id!);
                await _refreshTasks();
              },
              background: Container(
                alignment: Alignment.centerRight,
                color: Colors.red,
                padding: const EdgeInsets.only(right: 16),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              child: InkWell(
                onTap: () async {
                  if (selectedId == null || task.id == null) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          TaskEditScreen(taskListId: selectedId, task: task),
                    ),
                  );
                  await _refreshTasks();
                },
                child: ListTile(
                  leading: Checkbox(
                    value: completed,
                    onChanged: (v) async {
                      if (task.id == null || selectedId == null) return;
                      try {
                        await _getRepo().completeTask(
                          selectedId,
                          task.id!,
                          v ?? false,
                        );
                      } catch (e, st) {
                        logError('Task completion is waiting for sync', e, st);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Could not sync with Google Tasks. Please try again.',
                              ),
                            ),
                          );
                        }
                      }
                      if (mounted) await _refreshTasks();
                    },
                  ),
                  title: Text(
                    task.title ?? '(no title)',
                    style: TextStyle(
                      decoration: completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  trailing: metadata.frequency == null
                      ? null
                      : const Icon(
                          Icons.repeat,
                          semanticLabel: 'Repeating task',
                        ),
                  subtitle: metadata.notes.isNotEmpty
                      ? Text(metadata.notes)
                      : null,
                ),
              ),
            );
          }),
        ];
      }).toList(),
    );
  }

  Future<void> _loadData() async {
    final repo = context.read<TasksRepository>();
    setState(() => _loading = true);
    try {
      if (repo.selectedTasklistId == null) {
        final id = await repo.resolveDefaultTasklistId();
        await repo.selectTasklist(id);
      }
      await _refreshLists();
      await _refreshTasks();
    } catch (e, st) {
      logError('Failed to load tasks', e, st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load tasks: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshLists() async {
    final lists = await context.read<TasksRepository>().getTaskLists();
    if (mounted) {
      setState(() => _taskLists = lists);
    }
  }

  Future<void> _refreshTasks() async {
    final repo = context.read<TasksRepository>();
    final id = repo.selectedTasklistId;
    if (id == null) return;
    final tasks = await repo.getTasks(id);
    if (mounted) {
      setState(() => _tasks = tasks);
      WidgetService.updateWidget(
        _tasks,
        taskListName: _selectedTaskListTitle(),
      );
    }
  }

  /// Builds the task list popup shown under the app bar title.
  ///
  /// Every entry is a [TrailingCheckedMenuItem] so the selected list is marked
  /// with a checkmark on the right, matching the app bar overflow menu.
  List<PopupMenuEntry<String>> _buildTaskListMenu(String? selectedId) {
    final items = <PopupMenuEntry<String>>[];
    for (final list in _taskLists) {
      final id = list.id;
      if (id == null) continue;
      items.add(
        TrailingCheckedMenuItem<String>(
          value: id,
          label: list.title ?? 'Unnamed list',
          checked: id == selectedId,
        ),
      );
    }
    return items;
  }

  /// Switches to the task list chosen from the title popup.
  Future<void> _handleTaskListSelected(String taskListId) async {
    await _getRepo().selectTasklist(taskListId);
    await _refreshTasks();
  }

  Future<void> _openWidgetColorConfig() async {
    final initial = await WidgetColorService.loadConfig();
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => WidgetColorConfigDialog(
        initial: initial,
        onSaved: (config) async {
          await WidgetColorService.saveConfig(config);
          await WidgetService.refreshWidget();
        },
      ),
    );
  }

  Future<void> _handleAppBarAction(_AppBarAction action) async {
    switch (action) {
      case _AppBarAction.toggleCompleted:
        await _getRepo().setShowCompleted(!_getRepo().showCompleted);
        break;
      case _AppBarAction.widgetColors:
        await _openWidgetColorConfig();
        break;
      case _AppBarAction.deleteCompleted:
        await _deleteCompletedTasks();
        break;
      case _AppBarAction.signOut:
        await _signOut();
        break;
    }
  }

  Future<void> _deleteCompletedTasks() async {
    final repo = context.read<TasksRepository>();
    final id = repo.selectedTasklistId;
    if (id == null) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete completed tasks?'),
            content: const Text(
              'This will permanently remove all completed tasks. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    final progress = ValueNotifier<String>('Preparing deletion…');
    final navigator = Navigator.of(context, rootNavigator: true);
    final dialog = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Deleting completed tasks'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              ValueListenableBuilder<String>(
                valueListenable: progress,
                builder: (_, value, _) => Text(value),
              ),
            ],
          ),
        ),
      ),
    );
    navigator.push(dialog);
    try {
      await repo.deleteCompletedTasks(
        id,
        onProgress: (deleted, total) {
          if (!mounted) return;
          progress.value = '$deleted/$total';
        },
      );
      await _refreshTasks();
    } catch (e, st) {
      logError('Failed to delete completed tasks', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete completed tasks: $e')),
        );
      }
    } finally {
      if (dialog.isActive) navigator.removeRoute(dialog);
      progress.dispose();
    }
  }

  Future<void> _signOut() async {
    final repo = context.read<TasksRepository>();
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Sign out?'),
            content: const Text('Are you sure you want to sign out?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;
    await repo.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TasksRepository>();
    final selectedId = repo.selectedTasklistId;
    final selectedList = _taskLists.firstWhere(
      (l) => l.id == selectedId,
      orElse: () => TaskList(title: 'Tasks'),
    );
    final groups = _groupTasks(showCompleted: repo.showCompleted);
    final hasVisibleTasks = groups.any((g) => g.tasks.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        title: PopupMenuButton<String>(
          position: PopupMenuPosition.under,
          tooltip: 'Change task list',
          onOpened: () {
            _refreshLists();
          },
          onSelected: _handleTaskListSelected,
          itemBuilder: (context) => _buildTaskListMenu(selectedId),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(selectedList.title ?? 'Tasks'),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<_AppBarAction>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'Menu',
            position: PopupMenuPosition.under,
            offset: const Offset(0, _kOverflowMenuOffset),
            onSelected: _handleAppBarAction,
            itemBuilder: (context) => [
              TrailingCheckedMenuItem<_AppBarAction>(
                value: _AppBarAction.toggleCompleted,
                label: 'Show completed tasks',
                checked: repo.showCompleted,
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: _AppBarAction.widgetColors,
                child: Text('Widget colors'),
              ),
              const PopupMenuItem(
                value: _AppBarAction.deleteCompleted,
                child: Text('Delete completed tasks'),
              ),
              const PopupMenuItem(
                value: _AppBarAction.signOut,
                child: Text('Sign out'),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _refreshLists();
                await _refreshTasks();
              },
              child: hasVisibleTasks
                  ? _buildGroupedTaskList(groups: groups)
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(16.0),
                      children: const [Center(child: Text('No tasks yet'))],
                    ),
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add task',
        onPressed: selectedId == null
            ? null
            : () async {
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => TaskEditScreen(taskListId: selectedId),
                  ),
                );
                await _refreshTasks();
              },
        child: const Icon(Icons.add),
      ),
    );
  }
}
