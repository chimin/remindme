import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:remindme/main.dart';
import 'package:remindme/screens/login_screen.dart';
import 'package:remindme/screens/task_home_screen.dart';
import 'package:remindme/services/tasks_repository.dart';
import 'golden_test_helper.dart';

class RequiredSignInRepository extends MockTasksRepository {
  int attempts = 0;
  bool fail = true;
  Completer<void>? pending;
  @override
  Future<void> signIn() async {
    attempts++;
    signingIn = true;
    notifyListeners();
    await pending?.future;
    signingIn = false;
    if (fail) {
      authError = 'Choose a Google account to continue.';
      notifyListeners();
    } else {
      authError = null;
      await super.signIn();
    }
  }
}

void main() {
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
  Future<void> mount(WidgetTester tester, RequiredSignInRepository repo) async {
    await repo.init();
    await tester.pumpWidget(
      ChangeNotifierProvider<TasksRepository>.value(
        value: repo,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: createAppTheme(),
          home: const AuthRouter(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('startup should require sign in when no account is remembered', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(360, 640);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);
    final repo = RequiredSignInRepository();
    addTearDown(repo.dispose);
    await mount(tester, repo);
    await tester.pumpAndSettle();
    expect(repo.attempts, 1);
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(
      find.text('Keep your tasks and reminders together.'),
      findsOneWidget,
    );
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.byType(TaskHomeScreen), findsNothing);
    expect(find.text('Sync your tasks across devices.'), findsOneWidget);
    final screenshot = await captureAndCompare(
      tester,
      find.byType(MaterialApp),
      'features/screenshots/login_screen/login_screen_when_sign_in_required.png',
      'sign_in_required',
    );
    expect(screenshot['pass'], isTrue);
  });
  testWidgets(
    'retry should start sign in again when the previous attempt was canceled',
    (tester) async {
      final repo = RequiredSignInRepository();
      addTearDown(repo.dispose);
      await mount(tester, repo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(repo.attempts, 2);
    },
  );
  testWidgets(
    'rebuild should avoid duplicate prompts when sign in is pending',
    (tester) async {
      final repo = RequiredSignInRepository()..pending = Completer<void>();
      addTearDown(repo.dispose);
      await mount(tester, repo);
      repo.notifyListeners();
      await tester.pump();
      expect(repo.attempts, 1);
      expect(find.text('Signing in...'), findsOneWidget);
      expect(find.text('Retry'), findsNothing);
      repo.pending!.complete();
      await tester.pumpAndSettle();
    },
  );
  testWidgets('startup should show tasks when sign in succeeds', (
    tester,
  ) async {
    final repo = RequiredSignInRepository()..fail = false;
    addTearDown(repo.dispose);
    await mount(tester, repo);
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.byType(TaskHomeScreen), findsOneWidget);
    expect(repo.attempts, 1);
  });
}
