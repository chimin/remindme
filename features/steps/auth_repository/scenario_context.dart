// ignore_for_file: invalid_use_of_visible_for_testing_member

import '../scenario_runner.dart';
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:remindme/services/auth_repository.dart';
import 'package:remindme/services/google_account_provider.dart';
import '../../../test/support/fake_account_provider.dart';

ScenarioCases defineScenarios() {
  final scenarios = <String, ScenarioFactory>{};

  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeAccountProvider provider;
  late AuthRepository auth;
  void prepareScenario() {
    SharedPreferences.setMockInitialValues({});
    provider = FakeAccountProvider();
    auth = AuthRepository(provider: provider);
  }

  void cleanupScenario() => auth.dispose();
  scenarios['0'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      await auth.init();
      state.next = () async {
        expect(auth.hasLinkedAccount, isFalse);
        expect(provider.links, 0);
        expect(provider.initializations, 0);
      };
    };
  };
  scenarios['1'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      SharedPreferences.setMockInitialValues({
        AuthRepository.accountPreference: 'test@example.com',
      });
      provider.tokenError = StateError('offline');
      await auth.init();
      state.next = () async {
        expect(auth.signedIn, isTrue);
        expect(auth.client, isNotNull);
        expect(provider.authorizations, 0);
      };
    };
  };
  scenarios['2'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      await auth.init();
      await auth.signIn();
      state.next = () async {
        expect(auth.userEmail, 'test@example.com');
        expect(
          (await SharedPreferences.getInstance()).getString(
            AuthRepository.accountPreference,
          ),
          'test@example.com',
        );
        expect(provider.forgets, 0);
      };
    };
  };
  scenarios['3'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      provider.linkError = const AccountException(
        AccountFailure.canceled,
        'Canceled',
      );
      await auth.signIn();
      state.next = () async {
        expect(auth.signedIn, isFalse);
        expect(auth.signingIn, isFalse);
        state.next = () async {
          provider.linkError = null;
          await auth.signIn();
          state.next = () async {
            expect(auth.signedIn, isTrue);
            expect(provider.forgets, 0);
          };
        };
      };
    };
  };
  scenarios['4'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      provider.pendingLink = Completer();
      final first = auth.signIn();
      await Future<void>.delayed(Duration.zero);
      await auth.signIn();
      state.next = () async {
        expect(provider.links, 1);
        provider.pendingLink!.complete(
          GoogleAccountAuthorization(provider.account, 'token'),
        );
        await first;
      };
    };
  };
  scenarios['5'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      await auth.signIn();
      provider.account = const LinkedGoogleAccount('other@example.com');
      await auth.requestAuthorization();
      state.next = () async {
        expect(auth.userEmail, 'test@example.com');
        expect(auth.requiresReconnect, isTrue);
      };
    };
  };
  scenarios['6'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      auth.validateAccount = (_) async => throw const AccountException(
        AccountFailure.mismatch,
        'Wrong account',
      );
      await auth.signIn();
      state.next = () async {
        expect(auth.hasLinkedAccount, isFalse);
        expect(
          (await SharedPreferences.getInstance()).getString(
            AuthRepository.accountPreference,
          ),
          isNull,
        );
      };
    };
  };
  scenarios['7'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      provider.pendingLink = Completer();
      final first = auth.signIn();
      await Future<void>.delayed(Duration.zero);
      await auth.signOut();
      provider.pendingLink!.complete(
        GoogleAccountAuthorization(provider.account, 'token'),
      );
      await first;
      state.next = () async {
        expect(auth.signedIn, isFalse);
        expect(
          (await SharedPreferences.getInstance()).getString(
            AuthRepository.accountPreference,
          ),
          isNull,
        );
      };
    };
  };
  scenarios['8'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      SharedPreferences.setMockInitialValues({
        AuthRepository.accountPreference: 'test@example.com',
      });
      await auth.init();
      provider.pendingToken = Completer();
      final first = auth.accessToken();
      final second = auth.accessToken();
      await Future<void>.delayed(Duration.zero);
      state.next = () async {
        expect(provider.authorizations, 1);
        state.next = () async {
          provider.pendingToken!.complete('fresh');
          state.next = () async {
            expect(await first, 'fresh');
            expect(await second, 'fresh');
            expect(provider.interactiveRequests, [false]);
          };
        };
      };
    };
  };
  scenarios['9'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      await auth.signIn();
      provider.tokenError = const AccountException(
        AccountFailure.interactionRequired,
        'Consent required',
      );
      state.next = () async {
        await expectLater(
          auth.accessToken(rejectedToken: 'token'),
          throwsA(isA<AccountException>()),
        );
        expect(auth.signedIn, isTrue);
        expect(auth.requiresReconnect, isTrue);
        expect(provider.forgets, 0);
        expect(provider.interactiveRequests, [false]);
      };
    };
  };
  scenarios['10'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      await auth.signIn();
      final originalClient = auth.client;
      await auth.invalidateSession();
      await auth.requestAuthorization();
      state.next = () async {
        expect(auth.requiresReconnect, isFalse);
        expect(identical(originalClient, auth.client), isTrue);
      };
    };
  };
  scenarios['11'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      await auth.signIn();
      provider.forgetError = StateError('offline');
      await auth.signOut();
      state.next = () async {
        expect(auth.signedIn, isFalse);
        expect(auth.client, isNull);
        expect(
          (await SharedPreferences.getInstance()).getString(
            AuthRepository.accountPreference,
          ),
          isNull,
        );
      };
    };
  };
  scenarios['12'] = (state) async {
    addTearDown(cleanupScenario);
    prepareScenario();
    state.next = () async {
      auth.onSignedIn = () async => throw StateError('offline');
      await auth.signIn();
      state.next = () async {
        expect(auth.signedIn, isTrue);
      };
    };
  };

  return scenarios;
}
