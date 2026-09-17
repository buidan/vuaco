import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

class VisionScanResult {
  final String fen;
  final double confidence;

  const VisionScanResult({required this.fen, required this.confidence});
}

class VisionScanException implements Exception {
  final String message;
  const VisionScanException(this.message);

  @override
  String toString() => 'VisionScanException: $message';
}

/// `POST /api/v1/vision/scan` (see backend/README.md and RULES_ENGINE.md's
/// "Board Setup" section) - a photo in, a best-effort FEN + confidence out.
/// Callers must treat the result as a *draft* to review, not ground truth:
/// real testing against the backend found accuracy varies by how sparse/
/// unusual the position is, which is exactly why this feeds into the
/// existing board editor for correction rather than starting a game
/// directly.
abstract class VisionRepository {
  Future<VisionScanResult> scanBoardPhoto(String token, Uint8List bytes, String mimeType);

  void close();
}

class HttpVisionRepository implements VisionRepository {
  final String baseUrl;
  final http.Client _client;

  HttpVisionRepository({required this.baseUrl, http.Client? client}) : _client = client ?? http.Client();

  @override
  void close() => _client.close();

  @override
  Future<VisionScanResult> scanBoardPhoto(String token, Uint8List bytes, String mimeType) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$baseUrl/vision/scan'),
            headers: {'Content-Type': mimeType, 'Authorization': 'Bearer $token'},
            body: bytes,
          )
          .timeout(const Duration(seconds: 30));
    } catch (e) {
      throw VisionScanException('Could not reach the backend: $e');
    }

    if (response.statusCode == 501) {
      throw const VisionScanException(
        'Cloud Vision board scan is not configured on this server. Paste a FEN or use the board editor instead.',
      );
    }
    if (response.statusCode != 200) {
      throw VisionScanException('Board scan failed (HTTP ${response.statusCode}): ${response.body}');
    }

    try {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      return VisionScanResult(
        fen: json['fen'] as String,
        confidence: (json['confidence'] as num).toDouble(),
      );
    } catch (e) {
      throw VisionScanException('Malformed board scan response: $e');
    }
  }
}
