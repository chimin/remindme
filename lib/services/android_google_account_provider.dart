import 'package:flutter/services.dart';
import 'package:google_account_android/google_account_android.dart';
import 'google_account_provider.dart';

class AndroidGoogleAccountProvider implements GoogleAccountProvider {
  final MethodChannel _channel = GoogleAccountAndroid.channel;

  Future<T> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return (await _channel.invokeMethod<T>(method, args))!;
    } on PlatformException catch (error) {
      final reason = switch (error.code) {
        'canceled' => AccountFailure.canceled,
        'interaction_required' => AccountFailure.interactionRequired,
        'configuration' => AccountFailure.configuration,
        _ => AccountFailure.temporary,
      };
      throw AccountException(
        reason,
        error.message ?? 'Google Tasks is unavailable.',
      );
    }
  }

  @override
  Future<void> initialize() async {}
  @override
  Future<GoogleAccountAuthorization> link({
    LinkedGoogleAccount? expectedAccount,
  }) async {
    final account =
        expectedAccount ??
        LinkedGoogleAccount(await _call<String>('chooseAccount'));
    return GoogleAccountAuthorization(
      account,
      await authorize(account, interactive: true),
    );
  }

  @override
  Future<String> authorize(
    LinkedGoogleAccount account, {
    bool interactive = false,
  }) => _call<String>('authorize', {
    'email': account.email,
    'interactive': interactive,
  });
  @override
  Future<void> invalidateToken(String token) async {
    await _call<bool>('invalidateToken', {'token': token});
  }

  @override
  Future<void> forget() async {}
  @override
  void dispose() {}
}
