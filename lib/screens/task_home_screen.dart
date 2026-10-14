import 'package:flutter/material.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:provider/provider.dart';

import '../services/tasks_repository.dart';
import '../utils/log.dart';

class TaskHomeScreen extends StatefulWidget {
  const TaskHomeScreen({super.key});

  @override
  State<TaskHomeScreen> createState() => _TaskHomeScreenState();
}

class _TaskHomeScreenState extends State<TaskHomeScreen> {
  bool _loading = false;
  List<TaskList> _taskLists = [];
  List<Task> _tasks = [];

  @override
  void initState() {
    super.initState();
    _loadData();
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
    }
  }

  Future<void> _showListSwitcher() async {
    await _refreshLists();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) {
        return ListView(
          shrinkWrap: true,
          children: _taskLists.map((list) {
            final selected = list.id == context.read<TasksRepository>().selectedTasklistId;
            return ListTile(
              title: Text(list.title ?? 'Unnamed list'),
              trailing: selected ? const Icon(Icons.check) : null,
              onTap: () async {
                Navigator.of(context).pop();
                if (list.id != null) {
                  await context.read<TasksRepository>().selectTasklist(list.id!);
                  await _refreshTasks();
                }
              },
            );
          }).toList(),
        );
      },
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
        title: Text(selectedList.title ?? 'Tasks'),
         actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _deleteCompletedTasks,
            tooltip: 'Delete completed tasks',
          ),
          IconButton(
            icon: const Icon(Icons.list),
            onPressed: _showListSwitcher,
            tooltip: 'Switch list',
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => repo.signOut(),
            tooltip: 'Sign out',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _tasks.isEmpty
              ? const Center(child: Text('No tasks yet'))
              : RefreshIndicator(
                  onRefresh: () async {
                    await _refreshLists();
                    await _refreshTasks();
                  },
                  child: ListView.builder(
                    itemCount: _tasks.length,
                    itemBuilder: (context, index) {
                      final task = _tasks[index];
                      return Dismissible(
                        key: Key(task.id ?? index.toString()),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async => task.id != null,
                        onDismissed: (_) async {
                          if (task.id == null || selectedId == null) return;
                          await repo.deleteTask(selectedId, task.id!);
                          await _refreshTasks();
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          color: Colors.red,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        child: ListTile(
                          leading: Checkbox(
                            value: task.status == 'completed',
                            onChanged: (v) async {
                              if (task.id == null || selectedId == null) return;
                              await repo.completeTask(selectedId, task.id!, v ?? false);
                              await _refreshTasks();
                            },
                          ),
                          title: Text(
                            task.title ?? '(no title)',
                            style: TextStyle(
                              decoration: task.status == 'completed'
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                          subtitle: (task.notes != null && task.notes!.isNotEmpty)
                              ? Text(task.notes!)
                              : null,
                          trailing: IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => TaskEditScreen(
                                    taskListId: selectedId!,
                                    task: task,
                                  ),
                                ),
                              );
                              await _refreshTasks();
                            },
                          ),
                        ),
                      );
                    },
                  ),
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

class TaskEditScreen extends StatefulWidget {
  final String taskListId;
  final Task? task;

  const TaskEditScreen({
    super.key,
    required this.taskListId,
    this.task,
  });

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _dueDate;
  bool _saving = false;
  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _titleController.text = widget.task!.title ?? '';
      _notesController.text = widget.task!.notes ?? '';
      if (widget.task!.due != null) {
        try {
          _dueDate = DateTime.tryParse(widget.task!.due!);
        } catch (_) {}
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = context.read<TasksRepository>();
      if (_isEditing) {
        await repo.updateTask(
          widget.taskListId,
          widget.task!.id!,
          title: _titleController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          completed: widget.task?.status == 'completed',
          due: _dueDate,
        );
      } else {
        await repo.createTask(
          widget.taskListId,
          title: _titleController.text.trim(),
          notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
          due: _dueDate,
        );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      logError('Failed to save task', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save task: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    if (!_isEditing) return;
    try {
      final repo = context.read<TasksRepository>();
      await repo.deleteTask(widget.taskListId, widget.task!.id!);
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      logError('Failed to delete task', e, st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete task: $e')),
        );
      }
    }
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? now,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _dueDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Task' : 'New Task'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _delete,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _notesController,
                decoration: const InputDecoration(labelText: 'Notes'),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _dueDate == null ? 'No due date' : 'Due: ${_dueDate!.toIso8601String().split('T')[0]}',
                    ),
                  ),
                  TextButton(onPressed: _pickDueDate, child: const Text('Set date')),
                  if (_dueDate != null)
                    TextButton(onPressed: () => setState(() => _dueDate = null), child: const Text('Clear')),
                ],
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving ? const CircularProgressIndicator() : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
