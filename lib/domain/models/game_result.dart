import 'side.dart';

enum GameOutcome { ongoing, redWins, blackWins, draw }

/// Xiangqi has no stalemate draw: a player with no legal moves loses,
/// whether or not their general is currently in check.
enum GameEndReason { checkmate, noLegalMoves }

class GameResult {
  final GameOutcome outcome;
  final GameEndReason? reason;

  const GameResult._(this.outcome, this.reason);

  const GameResult.ongoing() : this._(GameOutcome.ongoing, null);

  GameResult.win(Side winner, GameEndReason reason)
      : this._(winner == Side.red ? GameOutcome.redWins : GameOutcome.blackWins, reason);

  bool get isOngoing => outcome == GameOutcome.ongoing;

  Side? get winner => switch (outcome) {
        GameOutcome.redWins => Side.red,
        GameOutcome.blackWins => Side.black,
        _ => null,
      };

  @override
  String toString() => 'GameResult($outcome, $reason)';
}
