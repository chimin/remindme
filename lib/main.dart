import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'services/sync_service.dart';
import 'services/tasks_repository.dart';
import 'screens/login_screen.dart';
import 'screens/task_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final repo = TasksRepository();
  final syncService = SyncService(repo);

  // Trigger a full push+pull sync on every sign-in so the local cache is up to
  // date before the home screen is shown.
  repo.onSignedIn = () => syncService.syncOnSignIn();

  await repo.init();
  await syncService.init();

  runApp(
    ChangeNotifierProvider.value(
      value: repo,
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remind Me',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const AuthRouter(),
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
