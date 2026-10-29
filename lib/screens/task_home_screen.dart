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
enum _AppBarAction { widgetColors, signOut }

/// Home screen listing the tasks of the selected Google task list.
///
/// The app bar exposes two Material popup menus that share the same styling:
/// the title acts as a task list switcher (a [PopupMenuButton] with a
/// dropdown indicator) and the overflow button holds the app wide actions.
/// The task list menu marks the active list with a checkmark on the right.
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
  final Set<String> _collapsedGroups = {};
  List<TaskList> _taskLists = [];
  List<Task> _tasks = [];

  TasksRepository _getRepo() => context.read<TasksRepository>();
  String? _getSelectedId() => _getRepo().selectedTasklistId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  List<TaskGroup> _groupTasks() {
    final now = DateTime.now();
    final filtered = _tasks;
    final groups = groupTasksByDueDate(filtered, now, showCompleted: false);
    final completed = filtered
        .where((task) => task.status == 'completed')
        .toList();
    if (completed.isNotEmpty) {
      groups.add(
        TaskGroup(title: 'Completed', category: 'completed', tasks: completed),
      );
    }
    return groups;
  }

  Widget _buildGroupHeader(TaskGroup group) {
    final theme = Theme.of(context);
    final collapsible =
        group.category == 'overdue' || group.category == 'noDueDate';
    final showCount =
        group.tasks.length > 1 && (collapsible || group.category == 'today');
    final collapsed = _collapsedGroups.contains(group.category);
    final overdue = group.category == 'overdue';
    final parsed = DateTime.tryParse(group.title);
    final title = parsed == null
        ? group.title
        : formatTaskDate(parsed, DateTime.now());
    final content = Padding(
      padding: group.category == 'completed'
          ? const EdgeInsets.fromLTRB(12, 0, 4, 0)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: overdue
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          if (showCount)
            Text(
              group.tasks.length.toString(),
              key: ValueKey('category_count_${group.category}'),
              style: TextStyle(
                color: overdue
                    ? theme.colorScheme.error
                    : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (group.category == 'completed')
            IconButton(
              tooltip: 'Delete completed tasks',
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: _deleteCompletedTasks,
            ),
          if (collapsible) ...[
            const SizedBox(width: 12),
            Icon(collapsed ? Icons.expand_more : Icons.expand_less, size: 20),
          ],
        ],
      ),
    );
    return Padding(
      key: ValueKey('category_${group.category}_${group.title}'),
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Material(
        color: overdue
            ? theme.colorScheme.errorContainer.withValues(alpha: 0.5)
            : theme.colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(12),
        child: collapsible
            ? InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => setState(() {
                  if (collapsed) {
                    _collapsedGroups.remove(group.category);
                  } else {
                    _collapsedGroups.add(group.category);
                  }
                }),
                child: content,
              )
            : content,
      ),
    );
  }

  Widget? _taskSubtitle(
    Task task,
    TaskMetadata metadata, {
    required bool showDate,
  }) {
    final date = DateTime.tryParse(task.due ?? '');
    final dateLabel = showDate && date != null
        ? formatTaskDate(date, DateTime.now())
        : null;
    final frequency = metadata.frequency;
    if (dateLabel == null && frequency == null && metadata.notes.isEmpty) {
      return null;
    }
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (metadata.notes.isNotEmpty)
          Text(metadata.notes, maxLines: 2, overflow: TextOverflow.ellipsis),
        if (dateLabel != null || frequency != null)
          DefaultTextStyle(
            style: theme.textTheme.bodySmall!,
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (dateLabel != null) Text(dateLabel),
                if (frequency != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.repeat,
                        size: 14,
                        color: theme.textTheme.bodySmall?.color,
                        semanticLabel: 'Repeats',
                      ),
                      const SizedBox(width: 4),
                      Text(frequency),
                    ],
                  ),
              ],
            ),
          ),
      ],
    );
  }

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
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      children: groups.expand((group) {
        final tasks = group.tasks;

        return [
          _buildGroupHeader(group),
          if (!_collapsedGroups.contains(group.category))
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
                    contentPadding: EdgeInsets.zero,
                    minVerticalPadding: 8,
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
                          logError(
                            'Task completion is waiting for sync',
                            e,
                            st,
                          );
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
                        decoration: completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    subtitle: _taskSubtitle(
                      task,
                      metadata,
                      showDate:
                          group.category != 'today' &&
                          group.category != 'future',
                    ),
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
      case _AppBarAction.widgetColors:
        await _openWidgetColorConfig();
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
    final count = _tasks.where((task) => task.status == 'completed').length;
    if (count == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No completed tasks to delete')),
      );
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'Clear $count completed ${count == 1 ? 'task' : 'tasks'}?',
            ),
            content: const Text(
              'This will permanently remove all completed tasks. This action cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
                child: Text('Delete $count ${count == 1 ? 'task' : 'tasks'}'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    final progress = ValueNotifier<String>('Preparing deletion...');
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
          progress.value = '$deleted of $total deleted';
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
    final groups = _groupTasks();
    final hasVisibleTasks = groups.any((g) => g.tasks.isNotEmpty);

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: PopupMenuButton<String>(
          padding: EdgeInsets.zero,
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
              SizedBox(
                height: 48,
                child: Center(child: Text(selectedList.title ?? 'Tasks')),
              ),
              const Icon(Icons.arrow_drop_down),
            ],
          ),
        ),
        actions: [
          PopupMenuButton<_AppBarAction>(
            padding: EdgeInsets.zero,
            tooltip: 'Menu',
            position: PopupMenuPosition.under,

            onSelected: _handleAppBarAction,
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: _AppBarAction.widgetColors,
                child: Text('Widget appearance'),
              ),
              const PopupMenuItem(
                value: _AppBarAction.signOut,
                child: Text('Sign out'),
              ),
            ],
            child: const SizedBox(
              width: 48,
              height: 48,
              child: Icon(Icons.more_vert),
            ),
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
                      padding: const EdgeInsets.all(16),
                      children: [
                        const SizedBox(height: 40),
                        Icon(
                          Icons.task_alt_rounded,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Text(
                            'No tasks yet',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Center(
                          child: Text(
                            'Make room for what matters. Add a task.',
                          ),
                        ),
                      ],
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
