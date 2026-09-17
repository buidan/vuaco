import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vuaco/data/repositories/auth_repository.dart';

void main() {
  group('HttpAuthRepository', () {
    test('parses a successful guest login response', () async {
      late Uri capturedUri;
      late Map<String, dynamic> capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(
          jsonEncode({
            'token': 'jwt-123',
            'user': {'id': 'user-1', 'username': 'Dan', 'elo': 1200},
          }),
          200,
        );
      });

      final repo = HttpAuthRepository(baseUrl: 'http://example.test/api/v1', client: client);
      final session = await repo.guestLogin('Dan');

      expect(capturedUri.toString(), 'http://example.test/api/v1/auth/guest');
      expect(capturedBody, {'username': 'Dan'});
      expect(session.token, 'jwt-123');
      expect(session.userId, 'user-1');
      expect(session.username, 'Dan');
    });

    test('throws AuthException on a non-200 response', () async {
      final client = MockClient((request) async => http.Response('bad', 400));
      final repo = HttpAuthRepository(baseUrl: 'http://example.test/api/v1', client: client);
      await expectLater(repo.guestLogin('Dan'), throwsA(isA<AuthException>()));
    });

    test('throws AuthException on malformed JSON', () async {
      final client = MockClient((request) async => http.Response('not json', 200));
      final repo = HttpAuthRepository(baseUrl: 'http://example.test/api/v1', client: client);
      await expectLater(repo.guestLogin('Dan'), throwsA(isA<AuthException>()));
    });
  });
}
