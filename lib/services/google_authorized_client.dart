import 'package:http/http.dart' as http;
import 'google_account_provider.dart';

class GoogleAuthorizedClient extends http.BaseClient {
  GoogleAuthorizedClient(
    this._inner, {
    required this.token,
    required this.isCurrent,
    required this.onUnauthorized,
  });
  final http.Client _inner;
  final Future<String> Function({String? rejectedToken}) token;
  final bool Function() isCurrent;
  final Future<void> Function() onUnauthorized;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final body = await request.finalize().toBytes();
    Future<http.StreamedResponse> attempt(String accessToken) {
      if (!isCurrent()) {
        throw const AccountException(
          AccountFailure.canceled,
          'Your sign-in session changed. Please retry.',
        );
      }
      final replay = http.Request(request.method, request.url)
        ..headers.addAll(request.headers)
        ..headers['Authorization'] = 'Bearer $accessToken'
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..persistentConnection = request.persistentConnection
        ..bodyBytes = body;
      return _inner.send(replay);
    }

    Future<void> checkCurrent(http.StreamedResponse response) async {
      if (!isCurrent()) {
        await response.stream.drain<void>();
        throw const AccountException(
          AccountFailure.canceled,
          'Your sign-in session changed. Please retry.',
        );
      }
    }

    final original = await token();
    var response = await attempt(original);
    await checkCurrent(response);
    if (response.statusCode == 401) {
      await response.stream.drain<void>();
      if (!isCurrent()) {
        throw const AccountException(
          AccountFailure.canceled,
          'Your sign-in session changed. Please retry.',
        );
      }
      response = await attempt(await token(rejectedToken: original));
      await checkCurrent(response);
      if (response.statusCode == 401) {
        await response.stream.drain<void>();
        if (!isCurrent()) {
          throw const AccountException(
            AccountFailure.canceled,
            'Your sign-in session changed. Please retry.',
          );
        }
        await onUnauthorized();
        throw const AccountException(
          AccountFailure.interactionRequired,
          'Please sign in again.',
        );
      }
    }
    if (!isCurrent()) {
      await response.stream.drain<void>();
      throw const AccountException(
        AccountFailure.canceled,
        'Your sign-in session changed. Please retry.',
      );
    }
    return response;
  }

  @override
  void close() => _inner.close();
}
