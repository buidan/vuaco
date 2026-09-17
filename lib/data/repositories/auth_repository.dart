import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/online_room.dart';

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);

  @override
  String toString() => 'AuthException: $message';
}

abstract class AuthRepository {
  /// Calls the backend's `POST /api/v1/auth/guest` (see backend/README.md's
  /// auth section - guest-only, no password, always creates a fresh user).
  Future<AuthSession> guestLogin(String username);

  void close();
}

class HttpAuthRepository implements AuthRepository {
  final String baseUrl;
  final http.Client _client;

  HttpAuthRepository({required this.baseUrl, http.Client? client}) : _client = client ?? http.Client();

  @override
  void close() => _client.close();

  @override
  Future<AuthSession> guestLogin(String username) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/auth/guest'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username}),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw AuthException('Could not reach the backend: $e');
    }

    if (response.statusCode != 200) {
      throw AuthException('Guest login failed (HTTP ${response.statusCode}): ${response.body}');
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final user = json['user'] as Map<String, dynamic>;
      return AuthSession(
        token: json['token'] as String,
        userId: user['id'] as String,
        username: user['username'] as String,
      );
    } catch (e) {
      throw AuthException('Malformed guest login response: $e');
    }
  }
}
