import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:remindme/services/google_authorized_client.dart';
import 'package:remindme/services/google_account_provider.dart';

void main() {
  test(
    'send should replay the body once when the server rejects an expired token',
    () async {
      final seen = <http.Request>[];
      final rejected = <String?>[];
      final client = GoogleAuthorizedClient(
        MockClient((request) async {
          seen.add(request);
          return http.Response('', seen.length == 1 ? 401 : 200);
        }),
        token: ({String? rejectedToken}) async {
          rejected.add(rejectedToken);
          return rejectedToken == null ? 'old' : 'new';
        },
        isCurrent: () => true,
        onUnauthorized: () async {},
      );
      addTearDown(client.close);
      await client.post(
        Uri.https('tasks.googleapis.com', '/tasks'),
        body: '{"title":"task"}',
      );
      expect(seen, hasLength(2));
      expect(seen.map((r) => r.body), everyElement('{"title":"task"}'));
      expect(seen.map((r) => r.headers['Authorization']), [
        'Bearer old',
        'Bearer new',
      ]);
      expect(rejected, [null, 'old']);
    },
  );
  test(
    'send should require reconnection when a fresh token is also rejected',
    () async {
      var requests = 0;
      var reconnects = 0;
      final client = GoogleAuthorizedClient(
        MockClient((_) async {
          requests++;
          return http.Response('', 401);
        }),
        token: ({String? rejectedToken}) async => 'token',
        isCurrent: () => true,
        onUnauthorized: () async {
          reconnects++;
        },
      );
      addTearDown(client.close);
      await expectLater(
        client.get(Uri.https('tasks.googleapis.com', '/tasks')),
        throwsA(isA<AccountException>()),
      );
      expect(requests, 2);
      expect(reconnects, 1);
    },
  );
  test(
    'send should avoid replaying a write when the connection drops',
    () async {
      var requests = 0;
      final client = GoogleAuthorizedClient(
        MockClient((_) async {
          requests++;
          throw const SocketException('offline');
        }),
        token: ({String? rejectedToken}) async => 'token',
        isCurrent: () => true,
        onUnauthorized: () async {},
      );
      addTearDown(client.close);
      await expectLater(
        client.post(Uri.https('tasks.googleapis.com', '/tasks')),
        throwsA(isA<SocketException>()),
      );
      expect(requests, 1);
    },
  );
  test('send should reject stale responses when the account changes', () async {
    var current = true;
    final client = GoogleAuthorizedClient(
      MockClient((_) async {
        current = false;
        return http.Response('{}', 200);
      }),
      token: ({String? rejectedToken}) async => 'token',
      isCurrent: () => current,
      onUnauthorized: () async {},
    );
    addTearDown(client.close);
    await expectLater(
      client.get(Uri.https('tasks.googleapis.com', '/tasks')),
      throwsA(isA<AccountException>()),
    );
  });
  test(
    'send should ignore rejected credentials when their account session was replaced',
    () async {
      var current = true;
      var tokens = 0;
      var reconnects = 0;
      final client = GoogleAuthorizedClient(
        MockClient((_) async {
          current = false;
          return http.Response('', 401);
        }),
        token: ({String? rejectedToken}) async {
          tokens++;
          return 'token';
        },
        isCurrent: () => current,
        onUnauthorized: () async {
          reconnects++;
        },
      );
      addTearDown(client.close);
      await expectLater(
        client.get(Uri.https('tasks.googleapis.com', '/tasks')),
        throwsA(
          isA<AccountException>().having(
            (error) => error.reason,
            'reason',
            AccountFailure.canceled,
          ),
        ),
      );
      expect(tokens, 1);
      expect(reconnects, 0);
    },
  );
}
