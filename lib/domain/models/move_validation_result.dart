import 'illegal_move_reason.dart';
import 'move.dart';

/// Result of validating (and, for [LegalMove], executing) a proposed move.
sealed class MoveValidationResult {
  const MoveValidationResult();
}

class LegalMove extends MoveValidationResult {
  final Move move;
  final bool leavesOpponentInCheck;
  final bool endsGame;

  const LegalMove(
    this.move, {
    this.leavesOpponentInCheck = false,
    this.endsGame = false,
  });
}

class IllegalMove extends MoveValidationResult {
  final IllegalMoveReason reason;
  final String message;

  const IllegalMove(this.reason, this.message);
}
