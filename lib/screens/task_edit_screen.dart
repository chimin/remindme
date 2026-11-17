import 'package:flutter/material.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:provider/provider.dart';

import '../services/tasks_repository.dart';
import '../models/task_metadata.dart';
import '../utils/log.dart';
import '../utils/task_grouping.dart';
import '../widgets/delete_task_confirmation_dialog.dart';

class TaskEditScreen extends StatefulWidget {
  final String taskListId;
  final Task? task;

  const TaskEditScreen({super.key, required this.taskListId, this.task});

  @override
  State<TaskEditScreen> createState() => _TaskEditScreenState();
}

class _TaskEditScreenState extends State<TaskEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime? _dueDate;
  bool _saving = false;
  String? _operation;
  String? _repeat;
  bool _repeatEdited = false;
  late TaskMetadata _metadata;
  bool get _isEditing => widget.task != null;
  late bool _isCompleted;
  bool get _readOnly => _isCompleted || _saving;

  @override
  void initState() {
    super.initState();
    _isCompleted = widget.task?.status == 'completed';
    _metadata = TaskMetadata.parse(widget.task?.notes);
    _repeat = _metadata.frequency;
    if (_isEditing) {
      _titleController.text = widget.task!.title ?? '';
      _notesController.text = _metadata.notes;
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

  Future<void> _save({bool markCompleted = false}) async {
    if (_saving || _isCompleted) return;
    if (!_formKey.currentState!.validate()) return;
    if (_repeat != null && _dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a due date for repeating tasks')),
      );
      return;
    }
    setState(() {
      _saving = true;
      _operation = markCompleted ? 'status' : 'save';
    });
    try {
      final repo = context.read<TasksRepository>();
      if (_repeat == null && (_repeatEdited || _metadata.frequency != null)) {
        _metadata.data.remove('recurrence');
      } else if (_repeat != null) {
        final previous = _metadata.data['recurrence'];
        _metadata.data['recurrence'] = <String, dynamic>{
          if (previous is Map) ...Map<String, dynamic>.from(previous),
          'frequency': _repeat,
          'interval': previous is Map && previous['frequency'] == _repeat
              ? previous['interval'] ?? 1
              : 1,
          'anchorDay':
              previous is Map &&
                  previous['frequency'] == _repeat &&
                  widget.task?.due != null &&
                  DateUtils.isSameDay(
                    DateTime.tryParse(widget.task!.due!),
                    _dueDate,
                  )
              ? previous['anchorDay'] ?? _dueDate!.day
              : _dueDate!.day,
        };
      }
      final notes = _metadata.encode(userNotes: _notesController.text.trim());
      if (_isEditing) {
        await repo.updateTask(
          widget.taskListId,
          widget.task!.id!,
          title: _titleController.text.trim(),
          notes: notes,
          completed: markCompleted,
          due: _dueDate,
        );
      } else {
        await repo.createTask(
          widget.taskListId,
          title: _titleController.text.trim(),
          notes: notes,
          due: _dueDate,
        );
      }
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      logError('Failed to save task', e, st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save task: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _operation = null;
        });
      }
    }
  }

  Future<void> _changeCompletion() async {
    if (_saving || !_isEditing || widget.task!.id == null) return;
    if (!_isCompleted) return _save(markCompleted: true);
    setState(() {
      _saving = true;
      _operation = 'status';
    });
    try {
      await context.read<TasksRepository>().completeTask(
        widget.taskListId,
        widget.task!.id!,
        false,
      );
      if (mounted) setState(() => _isCompleted = false);
    } catch (error, stack) {
      logError('Failed to mark task as incomplete', error, stack);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to mark task as incomplete: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _operation = null;
        });
      }
    }
  }

  Widget _actionIcon(String operation, IconData icon) => _operation == operation
      ? const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
      : Icon(icon);

  Future<void> _delete() async {
    if (!_isEditing || _saving || widget.task!.id == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          DeleteTaskConfirmationDialog(taskTitle: widget.task!.title ?? ''),
    );
    if (confirmed != true || !mounted || _saving) return;
    setState(() {
      _saving = true;
      _operation = 'delete';
    });
    try {
      final repo = context.read<TasksRepository>();
      await repo.deleteTask(widget.taskListId, widget.task!.id!);
      if (mounted && ModalRoute.of(context)?.isCurrent == true) {
        Navigator.of(context).pop();
      }
    } catch (e, st) {
      logError('Failed to delete task', e, st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete task: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _operation = null;
        });
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

  Widget _buildCompletedBadge(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? const Color(0xFFB3E3C3) : const Color(0xFF24583C);
    return Semantics(
      liveRegion: true,
      child: Container(
        key: const ValueKey('completed_task_badge'),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: dark ? const Color(0xFF243D30) : const Color(0xFFE0EFE5),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, size: 20, color: foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'This task is completed',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isCompleted
              ? 'View task'
              : _isEditing
              ? 'Edit task'
              : 'New task',
        ),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete task',
              icon: _actionIcon('delete', Icons.delete_outline),
              onPressed: _saving ? null : _delete,
            ),
          if (!_isCompleted)
            IconButton(
              tooltip: 'Save task',
              icon: _actionIcon('save', Icons.save_outlined),
              onPressed: _saving ? null : () => _save(),
            ),
        ],
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_isCompleted) ...[
                          _buildCompletedBadge(context),
                          const SizedBox(height: 24),
                        ],
                        TextFormField(
                          key: const ValueKey('task_title'),
                          controller: _titleController,
                          readOnly: _readOnly,
                          decoration: const InputDecoration(
                            labelText: 'Title',
                            hintText: 'What do you need to do?',
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Title is required'
                              : null,
                          autofocus: !_isEditing,
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          key: const ValueKey('task_notes'),
                          controller: _notesController,
                          readOnly: _readOnly,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            hintText: 'Add a few details',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          key: const ValueKey('due_date_field'),
                          onTap: _readOnly ? null : _pickDueDate,
                          borderRadius: BorderRadius.circular(16),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Due date',
                              prefixIcon: const Icon(
                                Icons.calendar_today_outlined,
                              ),
                              suffixIcon: _readOnly
                                  ? null
                                  : _dueDate == null
                                  ? const Icon(Icons.chevron_right)
                                  : IconButton(
                                      tooltip: 'Clear due date',
                                      icon: const Icon(Icons.clear),
                                      onPressed: () =>
                                          setState(() => _dueDate = null),
                                    ),
                            ),
                            child: Text(
                              _dueDate == null
                                  ? 'No due date'
                                  : formatTaskDate(_dueDate!, DateTime.now()),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _repeat ?? 'never',
                          decoration: const InputDecoration(
                            labelText: 'Repeat',
                            prefixIcon: Icon(Icons.repeat),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'never',
                              child: Text('Never'),
                            ),
                            DropdownMenuItem(
                              value: 'daily',
                              child: Text('Daily'),
                            ),
                            DropdownMenuItem(
                              value: 'weekly',
                              child: Text('Weekly'),
                            ),
                            DropdownMenuItem(
                              value: 'monthly',
                              child: Text('Monthly'),
                            ),
                            DropdownMenuItem(
                              value: 'yearly',
                              child: Text('Yearly'),
                            ),
                          ],
                          onChanged: _readOnly
                              ? null
                              : (value) => setState(() {
                                  _repeatEdited = true;
                                  _repeat = value == 'never' ? null : value;
                                }),
                        ),
                        const SizedBox(height: 24),
                        const Spacer(),
                        if (_isEditing)
                          FilledButton(
                            onPressed: _saving ? null : _changeCompletion,
                            child: _operation == 'status'
                                ? _actionIcon('status', Icons.check)
                                : Text(
                                    _isCompleted
                                        ? 'Mark as incomplete'
                                        : 'Mark as completed',
                                  ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
