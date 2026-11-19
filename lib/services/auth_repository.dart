import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'google_account_provider.dart';
import 'google_account_provider_factory.dart';
import 'google_authorized_client.dart';
import '../utils/log.dart';

class AuthRepository extends ChangeNotifier {
  AuthRepository({
    GoogleAccountProvider? provider,
    this.silentTimeout = const Duration(seconds: 10),
    this.sessionCleanupTimeout = const Duration(seconds: 30),
  }) : _provider = provider ?? createGoogleAccountProvider();

  static const accountPreference = 'remindme_google_account';
  static const reconnectPreference = 'remindme_google_reconnect';
  final GoogleAccountProvider _provider;
  final Duration silentTimeout;
  final Duration sessionCleanupTimeout;
  LinkedGoogleAccount? _account;
  http.Client? _client;
  String? _token;
  DateTime? _tokenTime;
  Future<String>? _tokenRequest;
  Future<void>? _initialization;
  Future<void>? _providerInitialization;
  Future<void> _preferenceWork = Future.value();
  bool initialized = false;
  bool signingIn = false;
  bool requiresReconnect = false;
  bool _disposed = false;
  int _generation = 0;
  String? authError;
  Future<void> Function()? onSignedIn;
  Future<void> Function(GoogleAccountAuthorization authorization)?
  validateAccount;

  bool get signedIn => _account != null;
  bool get hasLinkedAccount => signedIn;
  http.Client? get client => _client;
  String? get userEmail => _account?.email;
  String? get userDisplayName => userEmail;
  String? get userPhoto => null;

  void _publish() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _save(
    int generation,
    Future<void> Function(SharedPreferences) action,
  ) {
    final work = _preferenceWork.then((_) async {
      if (_disposed || generation != _generation) return;
      final prefs = await SharedPreferences.getInstance();
      await action(prefs);
    });
    _preferenceWork = work.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return work;
  }

  Future<void> _ready() => _providerInitialization ??= _provider
      .initialize()
      .catchError((Object error) {
        _providerInitialization = null;
        throw error;
      });

  Future<void> init() => _initialization ??= _initialize();
  Future<void> _initialize() async {
    final generation = _generation;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      if (_disposed || generation != _generation) return;
      final email = prefs.getString(accountPreference);
      if (email != null) {
        _account = LinkedGoogleAccount(email);
        requiresReconnect = prefs.getBool(reconnectPreference) ?? false;
        _client = _newClient(generation);
      }
    } finally {
      initialized = true;
      _publish();
    }
  }

  http.Client _newClient(int generation) => GoogleAuthorizedClient(
    http.Client(),
    token: ({String? rejectedToken}) {
      if (_disposed || generation != _generation) {
        throw const AccountException(
          AccountFailure.canceled,
          'Your sign-in session changed. Please retry.',
        );
      }
      return accessToken(rejectedToken: rejectedToken);
    },
    isCurrent: () =>
        !_disposed && generation == _generation && _account != null,
    onUnauthorized: () async {
      if (!_disposed && generation == _generation) await invalidateSession();
    },
  );

  Future<void> signIn() async {
    if (signingIn || _disposed) return;
    signingIn = true;
    authError = null;
    final generation = _generation;
    _publish();
    try {
      await _ready().timeout(silentTimeout);
      final authorization = await _provider.link(expectedAccount: _account);
      if (_disposed || generation != _generation) return;
      if (_account != null && !_account!.matches(authorization.account)) {
        throw const AccountException(
          AccountFailure.mismatch,
          'Sign in with the previously used Google account.',
        );
      }
      await validateAccount?.call(authorization);
      if (_disposed || generation != _generation) return;
      await _save(generation, (prefs) async {
        if (!await prefs.setString(
          accountPreference,
          authorization.account.email,
        )) {
          throw StateError('Unable to remember the linked account.');
        }
        await prefs.setBool(reconnectPreference, false);
        await prefs.remove('remindme_sign_in_succeeded');
      });
      if (_disposed || generation != _generation) return;
      _account = authorization.account;
      _token = authorization.accessToken;
      _tokenTime = DateTime.now();
      requiresReconnect = false;
      _client ??= _newClient(generation);
      _publish();
      try {
        await onSignedIn?.call();
      } catch (error, stack) {
        logError('Post-sign-in sync failed', error, stack);
      }
    } catch (error) {
      if (!_disposed && generation == _generation) {
        authError = error is AccountException
            ? error.reason == AccountFailure.canceled
                  ? 'Sign in was canceled. Retry to continue.'
                  : error.message
            : 'Unable to sign in. Please retry.';
        if (_account == null &&
            error is AccountException &&
            error.reason == AccountFailure.mismatch) {
          try {
            await _provider.forget().timeout(sessionCleanupTimeout);
          } catch (_) {
            /* A failed candidate must never become the cache owner. */
          }
        }
        if (_account != null &&
            error is AccountException &&
            (error.reason == AccountFailure.interactionRequired ||
                error.reason == AccountFailure.mismatch)) {
          await invalidateSession();
        }
      }
    } finally {
      if (!_disposed && generation == _generation) {
        signingIn = false;
        _publish();
      }
    }
  }

  Future<String> accessToken({String? rejectedToken}) {
    final inFlight = _tokenRequest;
    if (inFlight != null) return inFlight;
    final token = _token;
    if (token != null &&
        token != rejectedToken &&
        _tokenTime != null &&
        DateTime.now().difference(_tokenTime!) < const Duration(minutes: 50)) {
      return Future.value(token);
    }
    final generation = _generation;
    final request = _obtainToken(generation, rejectedToken);
    _tokenRequest = request;
    request.then<void>(
      (_) {
        if (identical(_tokenRequest, request)) _tokenRequest = null;
      },
      onError: (Object _, StackTrace _) {
        if (identical(_tokenRequest, request)) _tokenRequest = null;
      },
    );
    return request;
  }

  Future<String> _obtainToken(int generation, String? rejectedToken) async {
    final account = _account;
    if (account == null) {
      throw const AccountException(
        AccountFailure.interactionRequired,
        'Please sign in to continue.',
      );
    }
    try {
      await _ready().timeout(silentTimeout);
      if (rejectedToken != null) {
        await _provider.invalidateToken(rejectedToken).timeout(silentTimeout);
      }
      final token = await _provider.authorize(account).timeout(silentTimeout);
      if (_disposed || generation != _generation) {
        throw const AccountException(
          AccountFailure.canceled,
          'Your sign-in session changed. Please retry.',
        );
      }
      _token = token;
      _tokenTime = DateTime.now();
      if (requiresReconnect) {
        requiresReconnect = false;
        await _save(generation, (prefs) async {
          await prefs.setBool(reconnectPreference, false);
        });
        _publish();
      }
      return token;
    } on AccountException catch (error) {
      if (generation == _generation &&
          !_disposed &&
          (error.reason == AccountFailure.interactionRequired ||
              error.reason == AccountFailure.mismatch)) {
        await invalidateSession();
      }
      rethrow;
    }
  }

  Future<void> requestAuthorization() => signIn();
  Future<void> invalidateSession() async {
    final generation = _generation;
    _token = null;
    _tokenTime = null;
    requiresReconnect = _account != null;
    await _save(generation, (prefs) async {
      await prefs.setBool(reconnectPreference, requiresReconnect);
    });
    _publish();
  }

  Future<void> signOut() async {
    final generation = ++_generation;
    _client?.close();
    _client = null;
    _account = null;
    _token = null;
    _tokenTime = null;
    _tokenRequest = null;
    requiresReconnect = false;
    signingIn = true;
    authError = null;
    _publish();
    try {
      await _save(generation, (prefs) async {
        await prefs.remove(accountPreference);
        await prefs.remove(reconnectPreference);
        await prefs.remove('remindme_sign_in_succeeded');
      });
      try {
        await _provider.forget().timeout(sessionCleanupTimeout);
      } catch (error, stack) {
        logError('Unable to forget Google session', error, stack);
      }
    } finally {
      signingIn = false;
      _publish();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    _client?.close();
    _provider.dispose();
    super.dispose();
  }
}
