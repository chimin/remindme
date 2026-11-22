import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/sync_service.dart';
import 'services/reminder_service.dart';
import 'services/auth_repository.dart';
import 'services/tasks_repository.dart';
import 'screens/login_screen.dart';
import 'screens/task_home_screen.dart';
import 'utils/log.dart';
import 'widgets/widget_task_navigator.dart';

Future<void> main() => startApp();

/// Shared production startup, with real authentication injectable by device tests.
Future<void> startApp({AuthRepository? authRepository}) async {
  WidgetsFlutterBinding.ensureInitialized();

  final repo = TasksRepository(authRepository: authRepository);
  final syncService = SyncService(repo);

  repo.onSignedIn = syncService.syncOnSignIn;
  repo.onRefreshTasks = (id) => syncService.sync(tasklistId: id);
  runApp(ChangeNotifierProvider.value(value: repo, child: const MyApp()));

  // Let the loading UI paint before starting storage and platform work.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(() async {
      await repo.init();
      if (repo.hasLinkedAccount) {
        await ReminderService.requestPermission();
        await repo.refreshReminders(notifyNow: true);
      }
    }());
    unawaited(_initializeBackgroundSync(syncService));
  });
}

Future<void> _initializeBackgroundSync(SyncService service) async {
  try {
    await service.init();
  } catch (error, stack) {
    logError('Unable to schedule background sync', error, stack);
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.showDebugBanner = false});

  final bool showDebugBanner;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ReminderService.channel.setMethodCallHandler((MethodCall call) async {
      if (call.method == 'openHome') {
        _navigatorKey.currentState?.popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ReminderService.channel.setMethodCallHandler(null);
    super.dispose();
  }

  bool _wasInBackground = false;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wasInBackground = true;
    } else if (state == AppLifecycleState.resumed && _wasInBackground) {
      _wasInBackground = false;
      final repo = context.read<TasksRepository>();
      if (repo.initialized) unawaited(repo.refreshReminders(notifyNow: true));
    }
  }

  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Remind Me',
      debugShowCheckedModeBanner: widget.showDebugBanner,
      navigatorKey: _navigatorKey,
      theme: createAppTheme(),
      home: WidgetTaskNavigator(
        navigatorKey: _navigatorKey,
        child: const AuthRouter(),
      ),
    );
  }
}

class AuthRouter extends StatelessWidget {
  const AuthRouter({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<TasksRepository>();
    if (repo.changingAccount) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!repo.initialized) {
      return Scaffold(
        body: Center(
          child: repo.initializationError == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Unable to start Remind Me. Please try again.'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: repo.init,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
        ),
      );
    }
    if (!repo.hasLinkedAccount) {
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
