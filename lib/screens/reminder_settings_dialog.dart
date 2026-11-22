import 'package:flutter/material.dart';

import '../services/reminder_service.dart';

class ReminderSettingsDialog extends StatefulWidget {
  const ReminderSettingsDialog({super.key, required this.settings});

  final ReminderSettings settings;

  @override
  State<ReminderSettingsDialog> createState() => _ReminderSettingsDialogState();
}

class _ReminderSettingsDialogState extends State<ReminderSettingsDialog> {
  late bool _enabled = widget.settings.enabled;
  final _formKey = GlobalKey<FormState>();
  late final _timeController = TextEditingController(
    text:
        '${widget.settings.hour.toString().padLeft(2, '0')}:${widget.settings.minute.toString().padLeft(2, '0')}',
  );

  @override
  void dispose() {
    _timeController.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final parts = _timeController.text.trim().split(':');
    Navigator.pop(
      context,
      ReminderSettings(
        enabled: _enabled,
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reminder settings'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Daily reminders',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              InputDecorator(
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _enabled ? 'On' : 'Off',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Switch(
                      value: _enabled,
                      onChanged: (value) => setState(() => _enabled = value),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Time (24-hour)',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _timeController,
                keyboardType: TextInputType.datetime,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  hintText: '08:00',
                  suffixIcon: const Icon(Icons.access_time),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 20,
                  ),
                ),
                validator: (value) =>
                    RegExp(
                      r'^([01]?\d|2[0-3]):[0-5]\d$',
                    ).hasMatch(value?.trim() ?? '')
                    ? null
                    : 'Enter a time from 00:00 to 23:59',
                onFieldSubmitted: (_) => _save(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
