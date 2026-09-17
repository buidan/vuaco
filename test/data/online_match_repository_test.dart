import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:vuaco/data/repositories/online_match_repository.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/game_result.dart';
import 'package:vuaco/domain/models/side.dart';

const _sampleState = {
  'roomId': 'room-1',
  'pin': 'ABC123',
  'status': 'active',
  'fen': 'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1',
  'sideToMove': 'red',
  'result': {'outcome': 'ongoing', 'reason': null},
  'players': {
    'red': {'userId': 'u1', 'username': 'Alice', 'connected': true},
    'black': {'userId': 'u2', 'username': 'Bob', 'connected': false},
  },
  'clock': {'enabled': true, 'redRemainingMs': 60000, 'blackRemainingMs': 55000},
  'history': [
    {'notation': 'e3-e4', 'isCheck': false},
  ],
};

void main() {
  group('SocketIoOnlineMatchRepository REST calls', () {
    test('createRoom parses the created room + share link', () async {
      late Map<String, dynamic> capturedBody;
      late String? authHeader;
      final client = MockClient((request) async {
        capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
        authHeader = request.headers['Authorization'];
        return http.Response(
          jsonEncode({'roomId': 'room-1', 'pin': 'ABC123', 'shareLink': 'vuaco://join?pin=ABC123', 'state': _sampleState}),
          200,
        );
      });

      final repo = SocketIoOnlineMatchRepository(
        restBaseUrl: 'http://example.test/api/v1',
        socketUrl: 'http://example.test',
        httpClient: client,
      );

      final created = await repo.createRoom('token-1', timeControlMinutes: 10, incrementSeconds: 5);

      expect(authHeader, 'Bearer token-1');
      expect(capturedBody, {'timeControlMinutes': 10, 'incrementSeconds': 5});
      expect(created.roomId, 'room-1');
      expect(created.pin, 'ABC123');
      expect(created.state.sideToMove, Side.red);
      expect(created.state.history, hasLength(1));
      expect(created.state.history.single.notation, 'e3-e4');
      expect(created.state.clock?.redRemainingMs, 60000);
      expect(created.state.result, isA<GameResult>());
      expect(created.state.result.isOngoing, isTrue);
      expect(created.state.black?.username, 'Bob');
    });

    test('joinRoomByPin parses the joined room state', () async {
      final client = MockClient((request) async => http.Response(jsonEncode({'state': _sampleState}), 200));
      final repo = SocketIoOnlineMatchRepository(
        restBaseUrl: 'http://example.test/api/v1',
        socketUrl: 'http://example.test',
        httpClient: client,
      );
      final state = await repo.joinRoomByPin('token-1', 'ABC123');
      expect(state.roomId, 'room-1');
      expect(state.red.username, 'Alice');
    });

    test('parses a finished game result with a win reason', () async {
      final finished = {
        ..._sampleState,
        'result': {'outcome': 'blackWins', 'reason': 'timeout'},
      };
      final client = MockClient((request) async => http.Response(jsonEncode({'state': finished}), 200));
      final repo = SocketIoOnlineMatchRepository(
        restBaseUrl: 'http://example.test/api/v1',
        socketUrl: 'http://example.test',
        httpClient: client,
      );
      final state = await repo.joinRoomByPin('token-1', 'ABC123');
      expect(state.result.isOngoing, isFalse);
      expect(state.result.winner, Side.black);
      expect(state.result.reason, GameEndReason.timeout);
    });

    test('throws OnlineMatchException on a non-200 response', () async {
      final client = MockClient((request) async => http.Response('nope', 404));
      final repo = SocketIoOnlineMatchRepository(
        restBaseUrl: 'http://example.test/api/v1',
        socketUrl: 'http://example.test',
        httpClient: client,
      );
      await expectLater(repo.joinRoomByPin('token-1', 'ZZZZZZ'), throwsA(isA<OnlineMatchException>()));
    });

    test('sendMove throws OnlineMatchException before connectLive is called', () async {
      final repo = SocketIoOnlineMatchRepository(restBaseUrl: 'http://x', socketUrl: 'http://x');
      await expectLater(
        repo.sendMove('room-1', const BoardPoint(3, 4), const BoardPoint(4, 4)),
        throwsA(isA<OnlineMatchException>()),
      );
    });
  });
}
