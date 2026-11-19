import 'dart:async';
import 'package:google_sign_in/google_sign_in.dart';
import '../config.dart';
import '../utils/google_config.dart';
import 'google_account_provider.dart';

class FlutterGoogleAccountProvider implements GoogleAccountProvider {
  FlutterGoogleAccountProvider({String? clientId})
    : _clientId = clientId ?? getGoogleIosClientId();
  final String _clientId;
  final GoogleSignIn _google = GoogleSignIn.instance;
  GoogleSignInAccount? _user;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _subscription;
  Future<void>? _initialization;

  Future<T> _run<T>(Future<T> Function() action) async {
    try {
      return await action();
    } on GoogleSignInException catch (error) {
      throw AccountException(
        switch (error.code) {
          GoogleSignInExceptionCode.canceled => AccountFailure.canceled,
          GoogleSignInExceptionCode.clientConfigurationError =>
            AccountFailure.configuration,
          GoogleSignInExceptionCode.uiUnavailable =>
            AccountFailure.interactionRequired,
          _ => AccountFailure.temporary,
        },
        error.code == GoogleSignInExceptionCode.clientConfigurationError
            ? 'Google sign in is not configured for this app.'
            : 'Unable to sign in. Please retry.',
      );
    }
  }

  @override
  Future<void> initialize() => _initialization ??=
      _run(() async {
        final clientId = _clientId;
        if (clientId.isEmpty) {
          throw const AccountException(
            AccountFailure.configuration,
            'Google sign in is not configured for this app.',
          );
        }
        await _google.initialize(
          clientId: clientId,
          serverClientId: getGoogleWebClientId().isEmpty
              ? null
              : getGoogleWebClientId(),
        );
        _subscription = _google.authenticationEvents.listen((event) {
          if (event is GoogleSignInAuthenticationEventSignIn) {
            _user = event.user;
          }
          if (event is GoogleSignInAuthenticationEventSignOut) _user = null;
        }, onError: (Object _) {});
      }).catchError((Object error) {
        _initialization = null;
        throw error;
      });

  Future<GoogleSignInAccount> _account(
    LinkedGoogleAccount account,
    bool interactive,
  ) async {
    if (_user == null) {
      final attempt = _google.attemptLightweightAuthentication();
      if (attempt != null) _user = await attempt;
    }
    if (interactive &&
        _user != null &&
        !account.matches(LinkedGoogleAccount(_user!.email))) {
      await _google.signOut();
      _user = null;
    }
    if (_user == null && interactive) _user = await _google.authenticate();
    final user = _user;
    if (user == null) {
      throw const AccountException(
        AccountFailure.interactionRequired,
        'Please sign in again.',
      );
    }
    if (!account.matches(LinkedGoogleAccount(user.email))) {
      throw const AccountException(
        AccountFailure.mismatch,
        'Sign in with the previously used Google account.',
      );
    }
    return user;
  }

  @override
  Future<GoogleAccountAuthorization> link({
    LinkedGoogleAccount? expectedAccount,
  }) => _run(() async {
    await initialize();
    if (expectedAccount != null) {
      return GoogleAccountAuthorization(
        expectedAccount,
        await authorize(expectedAccount, interactive: true),
      );
    }
    final user = _user ?? await _google.authenticate();
    _user = user;
    final account = LinkedGoogleAccount(user.email);
    return GoogleAccountAuthorization(
      account,
      await authorize(account, interactive: true),
    );
  });

  @override
  Future<String> authorize(
    LinkedGoogleAccount account, {
    bool interactive = false,
  }) => _run(() async {
    await initialize();
    final user = await _account(account, interactive);
    var auth = await user.authorizationClient.authorizationForScopes(
      googleTasksScopes,
    );
    if (auth == null && interactive) {
      auth = await user.authorizationClient.authorizeScopes(googleTasksScopes);
    }
    if (auth == null) {
      throw const AccountException(
        AccountFailure.interactionRequired,
        'Please sign in again.',
      );
    }
    return auth.accessToken;
  });
  @override
  Future<void> invalidateToken(String token) => _run(
    () =>
        _google.authorizationClient.clearAuthorizationToken(accessToken: token),
  );
  @override
  Future<void> forget() async {
    _user = null;
    if (_initialization != null) await _run(() => _google.signOut());
  }

  @override
  void dispose() {
    _subscription?.cancel();
  }
}
