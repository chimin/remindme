import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tasks_repository.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TasksRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.login),
          label: const Text('Continue with Google'),
          onPressed: repo.signedIn
              ? null
              : () async {
                  try {
                    await context.read<TasksRepository>().signIn();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Sign in failed: $e')),
                      );
                    }
                  }
                },
        ),
      ),
    );
  }
}
