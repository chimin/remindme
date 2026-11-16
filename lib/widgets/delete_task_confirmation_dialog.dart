import 'package:flutter/material.dart';

class DeleteTaskConfirmationDialog extends StatelessWidget {
  final String taskTitle;

  const DeleteTaskConfirmationDialog({super.key, required this.taskTitle});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Delete task?'),
      content: Text('$taskTitle\n\nThis action cannot be undone.'),
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
          child: const Text('Delete'),
        ),
      ],
    );
  }
}
