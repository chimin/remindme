import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_account_android/google_account_android.dart';
import 'package:remindme/services/android_google_account_provider.dart';
import 'package:remindme/services/google_account_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  Object? error;
  setUp(() {
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
  });
  tearDown(
    () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(GoogleAccountAndroid.channel, null),
  );
  test(
    'link should pin authorization to the selected account when linking starts',
    () async {
      final provider = AndroidGoogleAccountProvider();
      final result = await provider.link();
      expect(result.account.email, 'owner@example.com');
      expect(calls.map((c) => c.method), ['chooseAccount', 'authorize']);
      expect(calls.last.arguments, {
        'email': 'owner@example.com',
        'interactive': true,
      });
    },
  );
  test('authorize should prohibit native UI when restoring silently', () async {
    await AndroidGoogleAccountProvider().authorize(
      const LinkedGoogleAccount('owner@example.com'),
    );
    expect(calls.single.arguments['interactive'], isFalse);
  });
  test(
    'reconnect should bypass account selection when an account is remembered',
    () async {
      await AndroidGoogleAccountProvider().link(
        expectedAccount: const LinkedGoogleAccount('owner@example.com'),
      );
      expect(calls.map((c) => c.method), ['authorize']);
    },
  );
  test(
    'authorize should normalize native resolution when interaction is required',
    () async {
      error = PlatformException(code: 'interaction_required');
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
    },
  );
}
