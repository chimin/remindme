import '../scenario_runner.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';
import 'package:remindme/services/flutter_google_account_provider.dart';
import 'package:remindme/services/google_account_provider.dart';
import '../../../test/support/fake_google_platform.dart';

ScenarioCases defineScenarios() {
  final scenarios = <String, ScenarioFactory>{};

  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeGooglePlatform platform;
  late FlutterGoogleAccountProvider provider;
  void prepareScenario() {
    platform = FakeGooglePlatform();
    GoogleSignInPlatform.instance = platform;
    provider = FlutterGoogleAccountProvider(
      clientId: 'test.apps.googleusercontent.com',
    );
  }

  Future<void> cleanupScenario() async {
    provider.dispose();
    unawaited(platform.events.close());
  }

  scenarios['0'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      final result = await provider.link();
      state.next = () async {
        expect(result.account.email, 'test@example.com');
        expect(result.accessToken, 'token');
        expect(platform.manualAttempts, 1);
        expect(platform.signOutCalls, 0);
      };
    };
  };
  scenarios['1'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      platform.restoreUser = true;
      state.next = () async {
        expect(
          await provider.authorize(
            const LinkedGoogleAccount('test@example.com'),
          ),
          'token',
        );
        expect(platform.silentAttempts, 1);
        expect(platform.manualAttempts, 0);
      };
    };
  };
  scenarios['2'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      state.next = () async {
        await expectLater(
          provider.authorize(const LinkedGoogleAccount('test@example.com')),
          throwsA(
            isA<AccountException>().having(
              (e) => e.reason,
              'reason',
              AccountFailure.interactionRequired,
            ),
          ),
        );
        expect(platform.manualAttempts, 0);
        expect(platform.signOutCalls, 0);
      };
    };
  };
  scenarios['3'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      platform.restoreUser = true;
      state.next = () async {
        await expectLater(
          provider.authorize(const LinkedGoogleAccount('other@example.com')),
          throwsA(
            isA<AccountException>().having(
              (e) => e.reason,
              'reason',
              AccountFailure.mismatch,
            ),
          ),
        );
      };
    };
  };
  scenarios['4'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      platform.restoreUser = true;
      platform.requireConsent = true;
      state.next = () async {
        await expectLater(
          provider.authorize(const LinkedGoogleAccount('test@example.com')),
          throwsA(
            isA<AccountException>().having(
              (e) => e.reason,
              'reason',
              AccountFailure.interactionRequired,
            ),
          ),
        );
        expect(platform.manualAttempts, 0);
      };
    };
  };
  scenarios['5'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      await provider.link();
      await provider.forget();
      state.next = () async {
        expect(platform.signOutCalls, 1);
        expect(platform.disconnectCalls, 0);
      };
    };
  };
  scenarios['6'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      provider.dispose();
      provider = FlutterGoogleAccountProvider(clientId: '');
      state.next = () async {
        await expectLater(
          provider.initialize(),
          throwsA(
            isA<AccountException>().having(
              (e) => e.reason,
              'reason',
              AccountFailure.configuration,
            ),
          ),
        );
      };
    };
  };

  return scenarios;
}
