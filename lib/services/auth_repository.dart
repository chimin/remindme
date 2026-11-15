import 'dart:async';

import 'package:flutter/foundation.dart' show ChangeNotifier;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:extension_google_sign_in_as_googleapis_auth/extension_google_sign_in_as_googleapis_auth.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';
import '../utils/google_config.dart';
import '../utils/log.dart';

/// Owns Google authentication, Tasks authorization, and saved-session recovery.
class AuthRepository extends ChangeNotifier {
  final GoogleSignIn _signIn = GoogleSignIn.instance;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _sub;
  GoogleSignInAccount? _currentUser;
  GoogleSignInClientAuthorization? _authorization;
  http.Client? _client;
  bool initialized = false;

  /// Fired after a successful sign-in once authorization is established.
  Future<void> Function()? onSignedIn;

  /// The authorized client for the current session, or null when signed out.
  http.Client? get client => _client;
  bool get signedIn =>
      _currentUser != null && _authorization != null && _client != null;
  String? get userDisplayName => _currentUser?.displayName;
  String? get userEmail => _currentUser?.email;
  String? get userPhoto => _currentUser?.photoUrl;

  bool signingIn = false;
  String? authError;
  bool _googleInitialized = false;
  bool _disposed = false;
  int _authGeneration = 0;
  static const _kSignInSucceededPrefKey = 'remindme_sign_in_succeeded';
  Future<void> _authPreferenceWork = Future.value();
  Future<void>? _authCleanup;
  bool _awaitingRestoreEvent = false;
  bool _signingOut = false;

  Future<void> _saveSignInSuccess(bool success, {int? generation}) {
    final result = _authPreferenceWork.then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (generation != null && (_disposed || generation != _authGeneration)) {
        return;
      }
      if (!await prefs.setBool(_kSignInSucceededPrefKey, success)) {
        throw StateError('Unable to save sign-in state');
      }
    });
    _authPreferenceWork = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  void _publishAuth() {
    if (!_disposed) notifyListeners();
  }

  void _clearAuthentication() {
    _authGeneration++;
    _awaitingRestoreEvent = false;
    _currentUser = null;
    _authorization = null;
    _client = null;
    signingIn = false;
  }

  Future<void> _authenticationFailed(Object error, StackTrace stack) {
    logError('Sign in failed', error, stack);
    return _resetSignInSession(
      error:
          error is GoogleSignInException &&
              error.code == GoogleSignInExceptionCode.canceled
          ? null
          : 'Unable to sign in. Please try again.',
    );
  }

  Future<void> _resetSignInSession({String? error, bool clearGoogle = true}) {
    final cleanup = _authCleanup;
    if (cleanup != null) return cleanup;
    _clearAuthentication();
    final generation = _authGeneration;
    signingIn = true;
    authError = error;
    _publishAuth();
    return _authCleanup = _finishSignInReset(generation, clearGoogle);
  }

  Future<void> _clearGoogleSession() async {
    _signingOut = true;
    try {
      await _signIn.signOut();
    } finally {
      // The platform and SDK relay sign-out through separate async streams.
      // Keep our own sign-out events suppressed until both have delivered.
      await Future<void>.delayed(Duration.zero);
      _signingOut = false;
    }
  }

  Future<void> _finishSignInReset(int generation, bool clearGoogle) async {
    try {
      try {
        await _saveSignInSuccess(false);
      } catch (error, stack) {
        logError('Failed to clear saved sign-in state', error, stack);
      }
      if (clearGoogle && _googleInitialized) {
        try {
          await _clearGoogleSession();
        } catch (error, stack) {
          logError('Failed to clear Google sign-in session', error, stack);
        }
      }
    } finally {
      _authCleanup = null;
      if (!_disposed && generation == _authGeneration) {
        signingIn = false;
        _publishAuth();
      }
    }
  }

  Future<void> _initializeGoogle() async {
    if (_googleInitialized) return;
    await _signIn.initialize(
      serverClientId: getGoogleWebClientId().isNotEmpty
          ? getGoogleWebClientId()
          : null,
    );
    _googleInitialized = true;
    _sub = _signIn.authenticationEvents.listen(
      (event) {
        if (_disposed || _authCleanup != null || _signingOut) return;
        if (event is GoogleSignInAuthenticationEventSignOut) {
          unawaited(_resetSignInSession(clearGoogle: false));
        } else if (event is GoogleSignInAuthenticationEventSignIn &&
            !signingIn &&
            (signedIn || _awaitingRestoreEvent)) {
          _awaitingRestoreEvent = false;
          unawaited(_acceptEvent(event.user));
        }
      },
      onError: (Object error, StackTrace stack) {
        // Active attempts handle their own Future errors. Ignore stale events
        // once the app has returned to the sign-in page.
        if (!_disposed &&
            !signingIn &&
            !_signingOut &&
            (signedIn || _awaitingRestoreEvent)) {
          unawaited(_authenticationFailed(error, stack));
        }
      },
    );
  }

  Future<void> _acceptEvent(GoogleSignInAccount user) async {
    signingIn = true;
    final generation = ++_authGeneration;
    _publishAuth();
    try {
      await _saveSignInSuccess(false);
      if (_disposed || generation != _authGeneration) return;
      await _completeSignIn(user, generation);
    } catch (error, stack) {
      if (generation == _authGeneration) {
        await _authenticationFailed(error, stack);
      }
    } finally {
      if (generation == _authGeneration) {
        signingIn = false;
        _publishAuth();
      }
    }
  }

  Future<void> init() async {
    signingIn = true;
    final generation = ++_authGeneration;
    try {
      final prefs = await SharedPreferences.getInstance();
      final canRestore = prefs.getBool(_kSignInSucceededPrefKey) ?? false;
      await _saveSignInSuccess(false);
      await _initializeGoogle();
      if (_disposed || generation != _authGeneration) return;
      if (canRestore) {
        _awaitingRestoreEvent = true;
        final attempt = _signIn.attemptLightweightAuthentication();
        if (attempt != null) {
          final account = await attempt;
          if (_disposed || generation != _authGeneration) return;
          _awaitingRestoreEvent = false;
          if (account != null) {
            await _completeSignIn(account, generation);
          } else {
            await _resetSignInSession();
          }
        }
      } else {
        await _resetSignInSession();
      }
    } catch (error, stack) {
      if (generation == _authGeneration) {
        await _authenticationFailed(error, stack);
      }
    } finally {
      signingIn = false;
      initialized = true;
      _publishAuth();
    }
  }

  Future<void> signIn() async {
    if (signingIn || _authCleanup != null || _signingOut || _disposed) return;
    _awaitingRestoreEvent = false;
    signingIn = true;
    authError = null;
    final generation = ++_authGeneration;
    _publishAuth();
    try {
      await _saveSignInSuccess(false);
      await _initializeGoogle();
      // A previous cleanup may have failed; retry before starting a new flow.
      await _clearGoogleSession();
      if (_disposed || generation != _authGeneration) return;
      final user = await _signIn.authenticate();
      await _completeSignIn(user, generation);
    } catch (error, stack) {
      if (generation == _authGeneration) {
        await _authenticationFailed(error, stack);
      }
    } finally {
      if (generation == _authGeneration) {
        signingIn = false;
        _publishAuth();
      }
    }
  }

  Future<void> signOut() async {
    if (_authCleanup != null) await _authCleanup;
    _signingOut = true;
    _clearAuthentication();
    signingIn = true;
    authError = null;
    _publishAuth();
    try {
      await _saveSignInSuccess(false);
      await _signIn.disconnect();
    } finally {
      await Future<void>.delayed(Duration.zero);
      _signingOut = false;
      signingIn = false;
      _publishAuth();
    }
  }

  /// Invalidates an expired session without revoking granted permissions.
  Future<void> invalidateSession() =>
      _resetSignInSession(error: 'Your session expired. Please sign in again.');

  Future<void> _completeSignIn(GoogleSignInAccount user, int generation) async {
    if (_disposed || generation != _authGeneration) return;
    final client = user.authorizationClient;
    final authorization =
        await client.authorizationForScopes(googleTasksScopes) ??
        await client.authorizeScopes(googleTasksScopes);
    if (_disposed || generation != _authGeneration) return;
    final authorizedClient = authorization.authClient(
      scopes: googleTasksScopes,
    );
    await _saveSignInSuccess(true, generation: generation);
    if (_disposed || generation != _authGeneration) return;
    _currentUser = user;
    _authorization = authorization;
    _client = authorizedClient;
    authError = null;
    _publishAuth();
    try {
      await onSignedIn?.call();
    } catch (error, stack) {
      logError('Post-sign-in callback failed', error, stack);
    }
  }

  Future<void> requestAuthorization() async {
    final user = _currentUser;
    if (user != null) await _acceptEvent(user);
  }

  @override
  void dispose() {
    _disposed = true;
    _authGeneration++;
    _sub?.cancel();
    super.dispose();
  }
}
