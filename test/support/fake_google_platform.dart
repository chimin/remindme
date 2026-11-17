import 'dart:async';

import 'package:google_sign_in_platform_interface/google_sign_in_platform_interface.dart';

class FakeGooglePlatform extends GoogleSignInPlatform {
  static const user = GoogleSignInUserData(
    email: 'test@example.com',
    id: 'user',
  );
  static const tokens = AuthenticationTokenData(idToken: 'id');
  final events = StreamController<AuthenticationEvent>();
  Object? initializationError;
  Future<void>? pendingInitialization;
  int initializationCalls = 0;
  bool requireConsent = false;
  Object? authError;
  Object? silentError;
  Object? disconnectError;
  Object? signOutError;
  bool restoreUser = false;
  bool eventOnlyRestore = false;
  int silentAttempts = 0;
  int manualAttempts = 0;
  int signOutCalls = 0;
  final operations = <String>[];
  int disconnectCalls = 0;
  int blockSignOutAfter = 0;
  Future<void>? pendingSignOut;
  final cleanupStarted = Completer<void>();
  final permissionStarted = Completer<void>();
  Object? permissionError;
  Future<ClientAuthorizationTokenData?>? pendingPermission;
  @override
  Stream<AuthenticationEvent> get authenticationEvents => events.stream;
  @override
  Future<void> init(InitParameters params) async {
    initializationCalls++;
    if (initializationError != null) throw initializationError!;
    await pendingInitialization;
  }

  @override
  Future<AuthenticationResults?>? attemptLightweightAuthentication(
    AttemptLightweightAuthenticationParameters params,
  ) {
    silentAttempts++;
    if (eventOnlyRestore) return null;
    if (silentError != null) return Future.error(silentError!);
    return Future.value(
      restoreUser
          ? const AuthenticationResults(
              user: user,
              authenticationTokens: tokens,
            )
          : null,
    );
  }

  @override
  Future<AuthenticationResults> authenticate(
    AuthenticateParameters params,
  ) async {
    manualAttempts++;
    operations.add('authenticate');
    if (authError != null) throw authError!;
    return const AuthenticationResults(
      user: user,
      authenticationTokens: tokens,
    );
  }

  @override
  Future<ClientAuthorizationTokenData?> clientAuthorizationTokensForScopes(
    ClientAuthorizationTokensForScopesParameters params,
  ) async {
    if (requireConsent && !params.request.promptIfUnauthorized) return null;
    if (permissionError != null) throw permissionError!;
    if (pendingPermission != null) {
      if (!permissionStarted.isCompleted) permissionStarted.complete();
      return pendingPermission;
    }
    return const ClientAuthorizationTokenData(accessToken: 'token');
  }

  @override
  bool supportsAuthenticate() => true;
  @override
  bool authorizationRequiresUserInteraction() => false;
  @override
  Future<void> disconnect(DisconnectParams params) async {
    disconnectCalls++;
    events.add(AuthenticationEventSignOut());
    if (disconnectError != null) throw disconnectError!;
  }

  @override
  Future<void> signOut(SignOutParams params) async {
    signOutCalls++;
    operations.add('signOut');
    events.add(AuthenticationEventSignOut());
    if (signOutError != null) throw signOutError!;
    if (pendingSignOut != null && signOutCalls > blockSignOutAfter) {
      if (!cleanupStarted.isCompleted) cleanupStarted.complete();
      await pendingSignOut;
    }
  }

  @override
  Future<ServerAuthorizationTokenData?> serverAuthorizationTokensForScopes(
    ServerAuthorizationTokensForScopesParameters params,
  ) async => null;
}
