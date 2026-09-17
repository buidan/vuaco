import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as socket_io;

import '../../domain/models/board_point.dart';
import '../../domain/models/game_result.dart';
import '../../domain/models/online_room.dart';
import '../../domain/models/side.dart';

class OnlineMatchException implements Exception {
  final String message;
  const OnlineMatchException(this.message);

  @override
  String toString() => 'OnlineMatchException: $message';
}

/// Thrown by [OnlineMatchRepository.sendMove] when the server rejects a
/// move (wrong turn, illegal move, game already over, ...). Carries the
/// same reason codes as the backend's `IllegalMoveReason` plus a couple of
/// room-specific ones ("not_a_participant", "room_not_found").
class MoveRejectedException implements Exception {
  final String reason;
  final String? message;
  const MoveRejectedException(this.reason, this.message);

  @override
  String toString() => 'MoveRejectedException($reason): ${message ?? ''}';
}

/// Server-authoritative online multiplayer, per docs/ARCHITECTURE.md
/// section 2: this repository never validates a move itself, it only
/// relays it to the backend (`POST /rooms`, `POST /rooms/join`, then the
/// `room:join`/`move:make` socket events) and reports back whatever the
/// server decided. `roomStateStream` is the single source of truth for
/// what's on the board - see `RoomState.fen`.
abstract class OnlineMatchRepository {
  Future<RoomCreatedInfo> createRoom(String token, {int? timeControlMinutes, int? incrementSeconds});
  Future<RoomState> joinRoomByPin(String token, String pin);

  /// Opens the realtime connection. Must be called (once) before
  /// [joinRoomLive] or [sendMove].
  Future<void> connectLive(String token);

  /// Attaches this connection to a room it was already created/joined via
  /// REST, returning the room's current state.
  Future<RoomState> joinRoomLive(String roomId);

  /// Throws [MoveRejectedException] if the server refuses the move -
  /// callers should catch this and show the reason as UX feedback, since
  /// the client did not validate the move itself (it may have, for
  /// highlighting purposes, but that's advisory only).
  Future<void> sendMove(String roomId, BoardPoint from, BoardPoint to);

  /// Broadcasts every `room:state` the server sends for as long as this
  /// connection is live - joins, opponent moves, clock timeouts, etc.
  Stream<RoomState> get roomStateStream;

  Future<void> disconnectLive();
  void close();
}

class SocketIoOnlineMatchRepository implements OnlineMatchRepository {
  final String restBaseUrl;
  final String socketUrl;
  final http.Client _httpClient;
  final StreamController<RoomState> _stateController = StreamController<RoomState>.broadcast();
  socket_io.Socket? _socket;

  SocketIoOnlineMatchRepository({
    required this.restBaseUrl,
    required this.socketUrl,
    http.Client? httpClient,
  }) : _httpClient = httpClient ?? http.Client();

  @override
  Stream<RoomState> get roomStateStream => _stateController.stream;

  @override
  Future<RoomCreatedInfo> createRoom(String token, {int? timeControlMinutes, int? incrementSeconds}) async {
    final json = await _postJson('$restBaseUrl/rooms', token, {
      'timeControlMinutes': ?timeControlMinutes,
      'incrementSeconds': ?incrementSeconds,
    });
    return RoomCreatedInfo(
      roomId: json['roomId'] as String,
      pin: json['pin'] as String,
      shareLink: json['shareLink'] as String,
      state: _parseRoomState(json['state'] as Map<String, dynamic>),
    );
  }

  @override
  Future<RoomState> joinRoomByPin(String token, String pin) async {
    final json = await _postJson('$restBaseUrl/rooms/join', token, {'pin': pin});
    return _parseRoomState(json['state'] as Map<String, dynamic>);
  }

  Future<Map<String, dynamic>> _postJson(String url, String token, Map<String, dynamic> body) async {
    final http.Response response;
    try {
      response = await _httpClient
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      throw OnlineMatchException('Could not reach the backend: $e');
    }
    if (response.statusCode != 200) {
      throw OnlineMatchException('Request to $url failed (HTTP ${response.statusCode}): ${response.body}');
    }
    try {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } catch (e) {
      throw OnlineMatchException('Malformed response from $url: $e');
    }
  }

  @override
  Future<void> connectLive(String token) {
    final completer = Completer<void>();
    final socket = socket_io.io(
      socketUrl,
      socket_io.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          // socket_io_client caches one Manager per host:port and reuses it
          // across `io()` calls unless told otherwise, so that two
          // connections to the same backend from the same process (e.g.
          // two OnlineMatchRepository instances in one test process, or a
          // stale connection left over from a previous session) don't
          // silently share - and contend over - one underlying transport.
          // Forcing a new one keeps each repository instance's connection
          // fully independent.
          .enableForceNew()
          .setAuth({'token': token})
          .build(),
    );
    _socket = socket;

    socket.onConnect((_) {
      if (!completer.isCompleted) completer.complete();
    });
    socket.onConnectError((err) {
      if (!completer.isCompleted) {
        completer.completeError(OnlineMatchException('Could not connect: $err'));
      }
    });
    socket.on('room:state', (data) {
      if (data is Map) {
        _stateController.add(_parseRoomState(Map<String, dynamic>.from(data)));
      }
    });

    socket.connect();
    return completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw const OnlineMatchException('Connection to backend timed out'),
    );
  }

  @override
  Future<RoomState> joinRoomLive(String roomId) async {
    final socket = _requireSocket();
    final ack = await socket.emitWithAckAsync('room:join', {'roomId': roomId});
    final map = Map<String, dynamic>.from(ack as Map);
    if (map['ok'] != true) {
      throw OnlineMatchException('Could not join room: ${map['error']}');
    }
    return _parseRoomState(Map<String, dynamic>.from(map['state'] as Map));
  }

  @override
  Future<void> sendMove(String roomId, BoardPoint from, BoardPoint to) async {
    final socket = _requireSocket();
    final ack = await socket.emitWithAckAsync('move:make', {
      'roomId': roomId,
      'from': {'row': from.row, 'col': from.col},
      'to': {'row': to.row, 'col': to.col},
    });
    final map = Map<String, dynamic>.from(ack as Map);
    if (map['ok'] != true) {
      throw MoveRejectedException(map['error'] as String? ?? 'unknown', map['message'] as String?);
    }
  }

  socket_io.Socket _requireSocket() {
    final socket = _socket;
    if (socket == null) {
      throw const OnlineMatchException('Not connected - call connectLive() first');
    }
    return socket;
  }

  @override
  Future<void> disconnectLive() async {
    _socket?.dispose();
    _socket = null;
  }

  @override
  void close() {
    _socket?.dispose();
    _socket = null;
    _httpClient.close();
    unawaited(_stateController.close());
  }
}

RoomState _parseRoomState(Map<String, dynamic> json) {
  final players = json['players'] as Map<String, dynamic>;
  final clockJson = json['clock'] as Map<String, dynamic>?;
  return RoomState(
    roomId: json['roomId'] as String,
    pin: json['pin'] as String,
    status: _parseStatus(json['status'] as String),
    fen: json['fen'] as String,
    sideToMove: json['sideToMove'] == 'red' ? Side.red : Side.black,
    result: _parseGameResult(json['result'] as Map<String, dynamic>),
    red: _parsePlayer(players['red'] as Map<String, dynamic>)!,
    black: _parsePlayer(players['black'] as Map<String, dynamic>?),
    clock: clockJson == null
        ? null
        : RoomClockInfo(
            enabled: clockJson['enabled'] as bool,
            redRemainingMs: clockJson['redRemainingMs'] as int,
            blackRemainingMs: clockJson['blackRemainingMs'] as int,
          ),
    history: (json['history'] as List<dynamic>)
        .map((e) => RoomMoveHistoryEntry(
              notation: (e as Map<String, dynamic>)['notation'] as String,
              isCheck: e['isCheck'] as bool,
            ))
        .toList(),
  );
}

RoomStatus _parseStatus(String status) => switch (status) {
      'waiting' => RoomStatus.waiting,
      'active' => RoomStatus.active,
      'finished' => RoomStatus.finished,
      _ => throw OnlineMatchException('Unknown room status "$status"'),
    };

RoomPlayerInfo? _parsePlayer(Map<String, dynamic>? json) {
  if (json == null) return null;
  return RoomPlayerInfo(
    userId: json['userId'] as String,
    username: json['username'] as String,
    connected: json['connected'] as bool,
  );
}

GameResult _parseGameResult(Map<String, dynamic> json) {
  final outcome = json['outcome'] as String;
  final reason = json['reason'] as String?;
  switch (outcome) {
    case 'ongoing':
      return const GameResult.ongoing();
    case 'draw':
      return const GameResult.draw();
    case 'redWins':
      return GameResult.win(Side.red, _parseReason(reason));
    case 'blackWins':
      return GameResult.win(Side.black, _parseReason(reason));
    default:
      throw OnlineMatchException('Unknown game outcome "$outcome"');
  }
}

GameEndReason _parseReason(String? reason) => switch (reason) {
      'checkmate' => GameEndReason.checkmate,
      'noLegalMoves' => GameEndReason.noLegalMoves,
      'timeout' => GameEndReason.timeout,
      'resignation' => GameEndReason.resignation,
      _ => throw OnlineMatchException('Unknown game end reason "$reason"'),
    };
