class LinkedGoogleAccount {
  const LinkedGoogleAccount(this.email);
  final String email;
  bool matches(LinkedGoogleAccount other) =>
      email.toLowerCase() == other.email.toLowerCase();
}

enum AccountFailure {
  canceled,
  interactionRequired,
  temporary,
  configuration,
  mismatch,
}

class AccountException implements Exception {
  const AccountException(this.reason, this.message);
  final AccountFailure reason;
  final String message;
  @override
  String toString() => message;
}

class GoogleAccountAuthorization {
  const GoogleAccountAuthorization(this.account, this.accessToken);
  final LinkedGoogleAccount account;
  final String accessToken;
}

abstract interface class GoogleAccountProvider {
  Future<void> initialize();
  Future<GoogleAccountAuthorization> link({
    LinkedGoogleAccount? expectedAccount,
  });
  Future<String> authorize(
    LinkedGoogleAccount account, {
    bool interactive = false,
  });
  Future<void> invalidateToken(String token);
  Future<void> forget();
  void dispose();
}
