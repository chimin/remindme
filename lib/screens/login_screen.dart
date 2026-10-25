import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tasks_repository.dart';
import '../utils/log.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TasksRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (repo.authError != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(repo.authError!),
              ),
            ElevatedButton.icon(
              icon: const Icon(Icons.login),
              label: Text(
                repo.signingIn ? 'Signing in...' : 'Continue with Google',
              ),
              onPressed: repo.signedIn || repo.signingIn
                  ? null
                  : () async {
                      try {
                        await context.read<TasksRepository>().signIn();
                      } catch (e, st) {
                        logError('Sign in failed', e, st);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Sign in failed: $e')),
                          );
                        }
                      }
                    },
            ),
          ],
        ),
      ),
    );
  }
}
