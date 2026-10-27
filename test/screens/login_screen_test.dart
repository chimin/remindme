import 'dart:async';
import 'package:remindme/screens/login_screen.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:remindme/main.dart';
import 'package:remindme/services/tasks_repository.dart';

import 'golden_test_helper.dart';

void main() {
  setUpAll(() async {
    final robotoBytes = await File(
      'test/fonts/roboto-regular.ttf',
    ).readAsBytes();
    final robotoLoader = FontLoader('Roboto')
      ..addFont(Future<ByteData>.value(ByteData.view(robotoBytes.buffer)));
    await robotoLoader.load();

    final materialIconsBytes = await File(
      'test/fonts/materialicons-regular.otf',
    ).readAsBytes();
    final materialIconsLoader = FontLoader('MaterialIcons')
      ..addFont(
        Future<ByteData>.value(ByteData.view(materialIconsBytes.buffer)),
      );
    await materialIconsLoader.load();
  });

  testWidgets(
    'sign in should show recovery and allow retry when authentication fails',
    (tester) async {
      expect(tester.view.devicePixelRatio, 2.0);
      expect(tester.view.physicalSize, const Size(720, 1280));
      final repo = FailingLoginRepository();
      addTearDown(repo.dispose);
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
      await repo.init();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(find.text('Unable to sign in. Please try again.'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull,
      );
      final result = await captureAndCompare(
        tester,
        find.byType(LoginScreen),
        'test/screens/golden/login_screen_failure.png',
        'login_screen_failure',
      );
      expect(result['pass'], isTrue);
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginScreen), findsNothing);
      expect(repo.signedIn, isTrue);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'view should allow custom dimensions when a test overrides defaults',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(800, 600);
      await tester.pumpWidget(
        const MaterialApp(debugShowCheckedModeBanner: false, home: SizedBox()),
      );
      expect(tester.view.devicePixelRatio, 1.0);
      expect(tester.view.physicalSize, const Size(800, 600));
      expect(
        MediaQuery.sizeOf(tester.element(find.byType(SizedBox).last)),
        const Size(800, 600),
      );
    },
  );

  testWidgets(
    'sign in should prevent duplicate attempts when authentication is pending',
    (tester) async {
      expect(tester.view.devicePixelRatio, 2.0);
      expect(tester.view.physicalSize, const Size(720, 1280));
      final repo = PendingLoginRepository();
      addTearDown(repo.dispose);
      await tester.pumpWidget(
        ChangeNotifierProvider<TasksRepository>.value(
          value: repo,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: createAppTheme(),
            home: const LoginScreen(),
          ),
        ),
      );
      await tester.tap(find.text('Continue with Google'));
      await tester.pump();
      expect(find.text('Signing in...'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNull,
      );
      repo.pending.complete();
      await tester.pumpAndSettle();
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(
        tester.widget<OutlinedButton>(find.byType(OutlinedButton)).onPressed,
        isNotNull,
      );
    },
  );

  testWidgets('sign in should show login screen when app starts unsigned in', (
    WidgetTester tester,
  ) async {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      MethodChannel('home_widget'),
      (_) async => null,
    );

    final mock = MockTasksRepository();
    final boundaryKey = GlobalKey();

    await tester.pumpWidget(
      ChangeNotifierProvider<TasksRepository>.value(
        value: mock,
        child: RepaintBoundary(
          key: boundaryKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: createAppTheme(),
            home: const AuthRouter(),
          ),
        ),
      ),
    );
    await mock.init();
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);

    final loginResult = await captureAndCompare(
      tester,
      find.byKey(boundaryKey),
      kLoginGoldenPath,
      'login_screen',
    );

    await tester.binding.runAsync(() async {
      await writeReport(
        threshold: kGoldenDiffThreshold,
        screenshots: <String, dynamic>{'login_screen': loginResult},
      );
    });

    expect(
      loginResult['pass'] as bool,
      isTrue,
      reason: 'login screen golden diff exceeded threshold',
    );
  });
}

class FailingLoginRepository extends MockTasksRepository {
  int attempts = 0;
  @override
  Future<void> signIn() async {
    if (++attempts == 1) {
      authError = 'Unable to sign in. Please try again.';
      notifyListeners();
    } else {
      authError = null;
      await super.signIn();
    }
  }
}

class PendingLoginRepository extends MockTasksRepository {
  final pending = Completer<void>();
  @override
  Future<void> signIn() async {
    signingIn = true;
    notifyListeners();
    await pending.future;
    signingIn = false;
    notifyListeners();
  }
}
