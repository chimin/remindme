import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remindme/main.dart';
import 'package:remindme/screens/login_screen.dart';
import 'package:remindme/services/auth_repository.dart';
import 'package:remindme/services/tasks_repository.dart';

class _PendingAuth extends AuthRepository {
  final ready = Completer<void>();
  bool started = false;

  @override
  Future<void> init() async {
    started = true;
    await ready.future;
  }
}

class _RetryRepository extends TasksRepository {
  @override
  Future<void> init() async {
    initializationError = null;
    initialized = true;
    notifyListeners();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          const EventChannel('home_widget/updates'),
          MockStreamHandler.inline(onListen: (_, events) {}),
        );
  });

  setUpAll(() async {
    for (final entry in {
      'Roboto': 'test/fonts/roboto-regular.ttf',
      'MaterialIcons': 'test/fonts/materialicons-regular.otf',
    }.entries) {
      final bytes = await File(entry.value).readAsBytes();
      await (FontLoader(
        entry.key,
      )..addFont(Future.value(ByteData.view(bytes.buffer)))).load();
    }
  });

  testWidgets(
    'startup should render before authentication when initialization is pending',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final auth = _PendingAuth();
      await startApp(authRepository: auth);
      expect(auth.started, isFalse);
      await tester.pump();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../screenshots/startup/startup_when_loading.png'),
      );
      auth.ready.complete();
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      final repo = tester
          .element(find.byType(LoginScreen))
          .read<TasksRepository>();
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
      auth.dispose();
    },
  );

  testWidgets(
    'startup should retry initialization when local data fails to load',
    (tester) async {
      final repo = _RetryRepository()
        ..initializationError = 'storage unavailable';
      await tester.pumpWidget(
        ChangeNotifierProvider<TasksRepository>.value(
          value: repo,
          child: const MyApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Unable to start Remind Me. Please try again.'),
        findsOneWidget,
      );
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('../screenshots/startup/startup_when_error.png'),
      );
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      repo.dispose();
    },
  );
}
