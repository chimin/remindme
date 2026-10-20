import 'package:flutter/material.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:provider/provider.dart';

import '../models/task_item.dart';
import '../services/tasks_repository.dart';
import '../services/widget_service.dart';
import '../utils/log.dart';
import '../utils/task_grouping.dart';
import 'task_edit_screen.dart';

class TaskHomeScreen extends StatefulWidget {
  const TaskHomeScreen({super.key});

  @override
  State<TaskHomeScreen> createState() => _TaskHomeScreenState();
}

class _TaskHomeScreenState extends State<TaskHomeScreen> {
  bool _loading = false;
  bool _showSwitcher = false;
  List<TaskList> _taskLists = [];
  List<Task> _tasks = [];

  TasksRepository _getRepo() => context.read<TasksRepository>();
  String? _getSelectedId() => _getRepo().selectedTasklistId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  List<TaskGroup> _groupTasks() =>
      groupTasksByDueDate(_tasks, DateTime.now());

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

  Widget _buildGroupedTaskList() {
    final selectedId = _getSelectedId();
    final groups = _groupTasks();

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
                  if (selectedId == null) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => TaskEditScreen(
                        taskListId: selectedId,
                        task: task,
                      ),
                    ),
                  );
                  await _refreshTasks();
                },
                child: ListTile(
                  leading: Checkbox(
                    value: completed,
                    onChanged: (v) async {
                      if (task.id == null || selectedId == null) return;
                      await _getRepo().completeTask(selectedId, task.id!, v ?? false);
                      await _refreshTasks();
                    },
                  ),
                  title: Text(
                    task.title ?? '(no title)',
                    style: TextStyle(
                      decoration: completed ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  subtitle: (task.notes != null && task.notes!.isNotEmpty)
                      ? Text(task.notes!)
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load tasks: $e')),
        );
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

  Future<void> _showListSwitcher() async {
    await _refreshLists();
    if (!mounted) return;
    setState(() => _showSwitcher = true);
  }

  Widget _buildListSwitcherOverlay() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0, top: 0),
              child: Material(
                elevation: 4,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.5,
                    maxWidth: 200,
                  ),
                  child: ListView(
                    shrinkWrap: true,
                    children: _taskLists.map((list) {
                      final selected = list.id ==
                          context.read<TasksRepository>().selectedTasklistId;
                      return ListTile(
                        title: Text(list.title ?? 'Unnamed list'),
                        trailing: selected ? const Icon(Icons.check) : null,
                        onTap: () async {
                          setState(() => _showSwitcher = false);
                          if (list.id != null) {
                            await context.read<TasksRepository>().selectTasklist(list.id!);
                            await _refreshTasks();
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  Future<void> _deleteCompletedTasks() async {
    final repo = context.read<TasksRepository>();
    final id = repo.selectedTasklistId;
    if (id == null) return;

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete completed tasks?'),
            content: const Text('This will permanently remove all completed tasks. This action cannot be undone.'),
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

    if (!confirmed) return;

    setState(() => _loading = true);
    try {
      await repo.deleteCompletedTasks(id);
      await _refreshTasks();
    } catch (e, st) {
      logError('Failed to delete completed tasks', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete completed tasks: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signOut() async {
    final repo = context.read<TasksRepository>();
    final confirmed = await showDialog<bool>(
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

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: () => setState(() => _showSwitcher = !_showSwitcher),
          child: Text(selectedList.title ?? 'Tasks'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _deleteCompletedTasks,
            tooltip: 'Delete completed tasks',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _signOut,
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                RefreshIndicator(
                  onRefresh: () async {
                    await _refreshLists();
                    await _refreshTasks();
                  },
                  child: _tasks.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.all(16.0),
                          children: const [
                            Center(child: Text('No tasks yet')),
                          ],
                        )
                      : _buildGroupedTaskList(),
                ),
                if (_showSwitcher) _buildListSwitcherOverlay(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
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
