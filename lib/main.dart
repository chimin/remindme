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

  runApp(ChangeNotifierProvider.value(value: repo, child: const MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.showDebugBanner = false});

  final bool showDebugBanner;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remind Me',
      debugShowCheckedModeBanner: showDebugBanner,
      theme: createAppTheme(),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!repo.signedIn) {
      return const LoginScreen();
    }
    return const TaskHomeScreen();
  }
}

/// Shared styling for the app and its screenshot fixtures.
ThemeData createAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF675080),
    primary: const Color(0xFF675080),
    surface: const Color(0xFFFAF8FC),
    error: const Color(0xFFB73545),
  );
  final rounded = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: 'Roboto',
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: const Color(0xFF211B2B),
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      titleSpacing: 24,
      titleTextStyle: const TextStyle(
        fontFamily: 'Roboto',
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: Color(0xFF211B2B),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF0EBF5),
      contentPadding: const EdgeInsets.all(20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: rounded,
        textStyle: const TextStyle(
          fontFamily: 'Roboto',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(0, 52),
        elevation: 0,
        shape: rounded,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 52),
        shape: rounded,
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      disabledElevation: 0,
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    popupMenuTheme: PopupMenuThemeData(
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: rounded,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    dividerTheme: const DividerThemeData(
      color: Color(0xFFE8E1EE),
      thickness: 1,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
      minVerticalPadding: 12,
    ),
  );
}
