import 'side.dart';

enum GameOutcome { ongoing, redWins, blackWins, draw }

/// Xiangqi has no stalemate draw: a player with no legal moves loses,
/// whether or not their general is currently in check. `timeout` and
/// `resignation` are never produced by the local Pass & Play engine
/// (`XiangqiEngine` in `../engine/xiangqi_engine.dart` has no clock UI or
/// resign action) - they exist here so the Phase 4 online-match domain
/// model (`online_room.dart`) can represent the backend's authoritative
/// `RoomManager` results, which do produce them, without a parallel result
/// type.
enum GameEndReason { checkmate, noLegalMoves, timeout, resignation }

class GameResult {
  final GameOutcome outcome;
  final GameEndReason? reason;

  const GameResult._(this.outcome, this.reason);

  const GameResult.ongoing() : this._(GameOutcome.ongoing, null);

  GameResult.win(Side winner, GameEndReason reason)
      : this._(winner == Side.red ? GameOutcome.redWins : GameOutcome.blackWins, reason);

  /// Not producible by anything in this codebase yet - no draw rule
  /// (perpetual check/repetition) is implemented anywhere, see
  /// RULES_ENGINE.md - but `GameOutcome.draw` exists as a type, so this
  /// needs to be constructible from it.
  const GameResult.draw() : this._(GameOutcome.draw, null);

  bool get isOngoing => outcome == GameOutcome.ongoing;

  Side? get winner => switch (outcome) {
        GameOutcome.redWins => Side.red,
        GameOutcome.blackWins => Side.black,
        _ => null,
      };

  @override
  String toString() => 'GameResult($outcome, $reason)';
}
