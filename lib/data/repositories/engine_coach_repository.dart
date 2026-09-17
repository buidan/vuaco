import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../domain/models/engine_analysis.dart';

class EngineCoachException implements Exception {
  final String message;
  const EngineCoachException(this.message);

  @override
  String toString() => 'EngineCoachException: $message';
}

abstract class EngineCoachRepository {
  /// Calls the backend's `POST /api/v1/engine/analyze` (see
  /// docs/ARCHITECTURE.md section 5 and backend/README.md) with [fen] - the
  /// same convention as `lib/domain/fen/fen_codec.dart` - and returns the
  /// ranked candidate lines. Throws [EngineCoachException] on any network,
  /// HTTP, or malformed-response failure.
  Future<EngineAnalysisResult> analyze(String fen, {int multiPv = 3, int? depth});

  void close();
}

class HttpEngineCoachRepository implements EngineCoachRepository {
  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  HttpEngineCoachRepository({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
  }) : _client = client ?? http.Client();

  @override
  void close() => _client.close();

  @override
  Future<EngineAnalysisResult> analyze(String fen, {int multiPv = 3, int? depth}) async {
    final uri = Uri.parse('$baseUrl/engine/analyze');
    final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({
              'fen': fen,
              'multiPv': multiPv,
              'depth': ?depth,
            }),
          )
          .timeout(timeout);
    } catch (e) {
      throw EngineCoachException('Could not reach the engine coach backend: $e');
    }

    if (response.statusCode != 200) {
      throw EngineCoachException(
        'Engine analysis failed (HTTP ${response.statusCode}): ${response.body}',
      );
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return _parseAnalysisResult(json);
    } catch (e) {
      throw EngineCoachException('Malformed engine analysis response: $e');
    }
  }

  static EngineAnalysisResult _parseAnalysisResult(Map<String, dynamic> json) {
    return EngineAnalysisResult(
      bestMove: json['bestMove'] as String?,
      ponder: json['ponder'] as String?,
      depthReached: json['depthReached'] as int,
      lines: (json['lines'] as List<dynamic>)
          .map((line) => _parseAnalysisLine(line as Map<String, dynamic>))
          .toList(),
    );
  }

  static EngineAnalysisLine _parseAnalysisLine(Map<String, dynamic> json) {
    return EngineAnalysisLine(
      multiPv: json['multiPv'] as int,
      depth: json['depth'] as int,
      scoreType: json['scoreType'] == 'mate' ? EngineScoreType.mate : EngineScoreType.centipawns,
      scoreValue: json['scoreValue'] as int,
      pvMoves: (json['pvMoves'] as List<dynamic>).cast<String>(),
    );
  }
}
