import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vuaco/data/repositories/engine_coach_repository.dart';
import 'package:vuaco/domain/models/engine_analysis.dart';

const _sampleResponse = {
  'bestMove': 'h2e2',
  'ponder': 'h9g7',
  'depthReached': 14,
  'lines': [
    {'multiPv': 1, 'depth': 14, 'scoreType': 'cp', 'scoreValue': 38, 'pvMoves': ['h2e2', 'h9g7']},
    {'multiPv': 2, 'depth': 14, 'scoreType': 'mate', 'scoreValue': -3, 'pvMoves': ['b2e2']},
  ],
};

void main() {
  group('HttpEngineCoachRepository', () {
    test('parses a successful response into EngineAnalysisResult', () async {
      late Uri capturedUri;
      late Map<String, dynamic> capturedBody;
      final client = MockClient((request) async {
        capturedUri = request.url;
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_sampleResponse), 200);
      });

      final repo = HttpEngineCoachRepository(baseUrl: 'http://example.test/api/v1', client: client);
      final result = await repo.analyze('startpos-fen w - - 0 1', multiPv: 2);

      expect(capturedUri.toString(), 'http://example.test/api/v1/engine/analyze');
      expect(capturedBody, {'fen': 'startpos-fen w - - 0 1', 'multiPv': 2});

      expect(result.bestMove, 'h2e2');
      expect(result.ponder, 'h9g7');
      expect(result.depthReached, 14);
      expect(result.lines, hasLength(2));
      expect(result.lines[0].scoreType, EngineScoreType.centipawns);
      expect(result.lines[0].scoreValue, 38);
      expect(result.lines[0].pvMoves, ['h2e2', 'h9g7']);
      expect(result.lines[1].scoreType, EngineScoreType.mate);
      expect(result.lines[1].scoreValue, -3);
    });

    test('includes depth in the request body when given', () async {
      Map<String, dynamic>? capturedBody;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode(_sampleResponse), 200);
      });
      final repo = HttpEngineCoachRepository(baseUrl: 'http://example.test/api/v1', client: client);
      await repo.analyze('fen', depth: 10);
      expect(capturedBody?['depth'], 10);
    });

    test('throws EngineCoachException on a non-200 response', () async {
      final client = MockClient((request) async => http.Response('bad request', 400));
      final repo = HttpEngineCoachRepository(baseUrl: 'http://example.test/api/v1', client: client);
      await expectLater(repo.analyze('fen'), throwsA(isA<EngineCoachException>()));
    });

    test('throws EngineCoachException on malformed JSON', () async {
      final client = MockClient((request) async => http.Response('not json', 200));
      final repo = HttpEngineCoachRepository(baseUrl: 'http://example.test/api/v1', client: client);
      await expectLater(repo.analyze('fen'), throwsA(isA<EngineCoachException>()));
    });

    test('throws EngineCoachException when the client itself throws', () async {
      final client = MockClient((request) async => throw Exception('network down'));
      final repo = HttpEngineCoachRepository(baseUrl: 'http://example.test/api/v1', client: client);
      await expectLater(repo.analyze('fen'), throwsA(isA<EngineCoachException>()));
    });
  });
}
