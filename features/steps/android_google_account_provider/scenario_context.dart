import '../scenario_runner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_account_android/google_account_android.dart';
import 'package:remindme/services/android_google_account_provider.dart';
import 'package:remindme/services/google_account_provider.dart';

ScenarioCases defineScenarios() {
  final scenarios = <String, ScenarioFactory>{};

  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  Object? error;
  void prepareScenario() {
    calls.clear();
    error = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GoogleAccountAndroid.channel, (call) async {
          calls.add(call);
          if (error != null) throw error!;
          return switch (call.method) {
            'chooseAccount' => 'owner@example.com',
            'authorize' => 'token',
            _ => true,
          };
        });
  }

  void cleanupScenario() => TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger
      .setMockMethodCallHandler(GoogleAccountAndroid.channel, null);
  scenarios['0'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      final provider = AndroidGoogleAccountProvider();
      final result = await provider.link();
      state.next = () async {
        expect(result.account.email, 'owner@example.com');
        expect(calls.map((c) => c.method), ['chooseAccount', 'authorize']);
        expect(calls.last.arguments, {
          'email': 'owner@example.com',
          'interactive': true,
        });
      };
    };
  };
  scenarios['1'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      await AndroidGoogleAccountProvider().authorize(
        const LinkedGoogleAccount('owner@example.com'),
      );
      state.next = () async {
        expect(calls.single.arguments['interactive'], isFalse);
      };
    };
  };
  scenarios['2'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      await AndroidGoogleAccountProvider().link(
        expectedAccount: const LinkedGoogleAccount('owner@example.com'),
      );
      state.next = () async {
        expect(calls.map((c) => c.method), ['authorize']);
      };
    };
  };
  scenarios['3'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      error = PlatformException(code: 'interaction_required');
      state.next = () async {
        await expectLater(
          AndroidGoogleAccountProvider().authorize(
            const LinkedGoogleAccount('owner@example.com'),
          ),
          throwsA(
            isA<AccountException>().having(
              (e) => e.reason,
              'reason',
              AccountFailure.interactionRequired,
            ),
          ),
        );
      };
    };
  };

  return scenarios;
}
