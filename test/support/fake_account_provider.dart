import 'dart:async';
import 'package:remindme/services/google_account_provider.dart';

class FakeAccountProvider implements GoogleAccountProvider {
  LinkedGoogleAccount account = const LinkedGoogleAccount('test@example.com');
  String token = 'token';
  Object? initializationError;
  Object? linkError;
  Object? tokenError;
  Object? forgetError;
  Completer<GoogleAccountAuthorization>? pendingLink;
  Completer<String>? pendingToken;
  int links = 0;
  int authorizations = 0;
  int invalidations = 0;
  int forgets = 0;
  int initializations = 0;
  bool disposed = false;
  final interactiveRequests = <bool>[];
  @override
  Future<void> initialize() async {
    initializations++;
    if (initializationError != null) throw initializationError!;
  }

  @override
  Future<GoogleAccountAuthorization> link({
    LinkedGoogleAccount? expectedAccount,
  }) async {
    links++;
    if (linkError != null) throw linkError!;
    if (pendingLink != null) return pendingLink!.future;
    return GoogleAccountAuthorization(account, token);
  }

  @override
  Future<String> authorize(
    LinkedGoogleAccount account, {
    bool interactive = false,
  }) async {
    authorizations++;
    interactiveRequests.add(interactive);
    if (tokenError != null) throw tokenError!;
    if (pendingToken != null) return pendingToken!.future;
    return token;
  }

  @override
  Future<void> invalidateToken(String token) async {
    invalidations++;
  }

  @override
  Future<void> forget() async {
    forgets++;
    if (forgetError != null) throw forgetError!;
  }

  @override
  void dispose() {
    disposed = true;
  }
}
