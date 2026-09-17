import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vuaco/data/repositories/vision_repository.dart';

const _sampleFen = 'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1';

void main() {
  group('HttpVisionRepository', () {
    test('sends the image bytes with the given content type and bearer token', () async {
      late Uri capturedUri;
      late String? capturedContentType;
      late String? capturedAuth;
      late List<int> capturedBody;

      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedContentType = request.headers['content-type'];
        capturedAuth = request.headers['Authorization'];
        capturedBody = request.bodyBytes;
        return http.Response(jsonEncode({'fen': _sampleFen, 'confidence': 0.92}), 200);
      });

      final repo = HttpVisionRepository(baseUrl: 'http://example.test/api/v1', client: client);
      final bytes = Uint8List.fromList([1, 2, 3, 4]);
      final result = await repo.scanBoardPhoto('token-1', bytes, 'image/png');

      expect(capturedUri.toString(), 'http://example.test/api/v1/vision/scan');
      expect(capturedContentType, 'image/png');
      expect(capturedAuth, 'Bearer token-1');
      expect(capturedBody, [1, 2, 3, 4]);
      expect(result.fen, _sampleFen);
      expect(result.confidence, 0.92);
    });

    test('gives a clear message for a 501 (Cloud Vision not configured)', () async {
      final client = MockClient((request) async => http.Response('', 501));
      final repo = HttpVisionRepository(baseUrl: 'http://example.test/api/v1', client: client);
      await expectLater(
        repo.scanBoardPhoto('t', Uint8List(0), 'image/jpeg'),
        throwsA(isA<VisionScanException>().having((e) => e.message, 'message', contains('not configured'))),
      );
    });

    test('throws VisionScanException on a non-200/501 response', () async {
      final client = MockClient((request) async => http.Response('bad image', 400));
      final repo = HttpVisionRepository(baseUrl: 'http://example.test/api/v1', client: client);
      await expectLater(repo.scanBoardPhoto('t', Uint8List(0), 'image/jpeg'), throwsA(isA<VisionScanException>()));
    });

    test('throws VisionScanException on malformed JSON', () async {
      final client = MockClient((request) async => http.Response('not json', 200));
      final repo = HttpVisionRepository(baseUrl: 'http://example.test/api/v1', client: client);
      await expectLater(repo.scanBoardPhoto('t', Uint8List(0), 'image/jpeg'), throwsA(isA<VisionScanException>()));
    });
  });
}
