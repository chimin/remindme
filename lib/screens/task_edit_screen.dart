import 'package:flutter/material.dart';
import 'package:googleapis/tasks/v1.dart';
import 'package:provider/provider.dart';

import '../services/tasks_repository.dart';
import '../models/task_metadata.dart';
import '../utils/log.dart';
import '../utils/task_grouping.dart';

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
  String? _repeat;
  bool _repeatEdited = false;
  late TaskMetadata _metadata;
  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_repeat != null && _dueDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choose a due date for repeating tasks')),
      );
      return;
    }
    setState(() => _saving = true);
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
          completed: widget.task?.status == 'completed',
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
      if (mounted) Navigator.of(context).pop();
    } catch (e, st) {
      logError('Failed to save task', e, st);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save task: $e')));
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete task: $e')));
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
        title: Text(_isEditing ? 'Edit task' : 'New task'),
        actions: [
          if (_isEditing)
            IconButton(
              tooltip: 'Delete task',
              icon: const Icon(Icons.delete_outline),
              onPressed: _saving ? null : _delete,
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
                        TextFormField(
                          controller: _titleController,
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
                          controller: _notesController,
                          decoration: const InputDecoration(
                            labelText: 'Notes',
                            hintText: 'Add a few details',
                          ),
                          maxLines: 3,
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          key: const ValueKey('due_date_field'),
                          onTap: _pickDueDate,
                          borderRadius: BorderRadius.circular(16),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Due date',
                              prefixIcon: const Icon(
                                Icons.calendar_today_outlined,
                              ),
                              suffixIcon: _dueDate == null
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
                          onChanged: (value) => setState(() {
                            _repeatEdited = true;
                            _repeat = value == 'never' ? null : value;
                          }),
                        ),
                        const SizedBox(height: 24),
                        const Spacer(),
                        FilledButton(
                          onPressed: _saving ? null : _save,
                          child: _saving
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  _isEditing ? 'Save changes' : 'Create task',
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
