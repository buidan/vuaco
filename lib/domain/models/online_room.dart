import 'game_result.dart';
import 'side.dart';

/// Mirrors the backend's `RoomStateSnapshot`/`RoomPlayerInfo`
/// (backend/src/rooms/roomManager.ts) - plain data only, no JSON or
/// socket knowledge (that's `lib/data/repositories/online_match_repository.dart`'s
/// job, same split as `EngineAnalysisResult`).
class RoomPlayerInfo {
  final String userId;
  final String username;
  final bool connected;

  const RoomPlayerInfo({required this.userId, required this.username, required this.connected});
}

class RoomClockInfo {
  final bool enabled;
  final int redRemainingMs;
  final int blackRemainingMs;

  const RoomClockInfo({required this.enabled, required this.redRemainingMs, required this.blackRemainingMs});
}

class RoomMoveHistoryEntry {
  final String notation;
  final bool isCheck;

  const RoomMoveHistoryEntry({required this.notation, required this.isCheck});
}

enum RoomStatus { waiting, active, finished }

/// A live snapshot of one multiplayer room, as broadcast over
/// `room:state`. The board itself is carried as [fen] (decode with
/// `FenCodec.decode` to render it with the same `XiangqiBoardView` Pass &
/// Play uses) rather than a `Board`, because that's exactly what comes
/// over the wire and there is no reason to eagerly decode it before the
/// presentation layer needs it.
class RoomState {
  final String roomId;
  final String pin;
  final RoomStatus status;
  final String fen;
  final Side sideToMove;
  final GameResult result;
  final RoomPlayerInfo red;
  final RoomPlayerInfo? black;
  final RoomClockInfo? clock;
  final List<RoomMoveHistoryEntry> history;

  const RoomState({
    required this.roomId,
    required this.pin,
    required this.status,
    required this.fen,
    required this.sideToMove,
    required this.result,
    required this.red,
    required this.black,
    required this.clock,
    required this.history,
  });
}

class RoomCreatedInfo {
  final String roomId;
  final String pin;
  final String shareLink;
  final RoomState state;

  const RoomCreatedInfo({required this.roomId, required this.pin, required this.shareLink, required this.state});
}

class AuthSession {
  final String token;
  final String userId;
  final String username;

  const AuthSession({required this.token, required this.userId, required this.username});
}
