import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/tasks_repository.dart';
import 'screens/login_screen.dart';
import 'screens/task_home_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TasksRepository()..init(),
      child: MaterialApp(
        title: 'Remind Me',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const AuthRouter(),
      ),
    );
  }
}

class AuthRouter extends StatelessWidget {
  const AuthRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TasksRepository>();
    if (!repo.initialized) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (!repo.signedIn) {
      return const LoginScreen();
    }
    return const TaskHomeScreen();
  }
}
