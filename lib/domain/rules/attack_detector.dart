import '../models/board.dart';
import '../models/board_point.dart';
import '../models/side.dart';
import 'piece_moves.dart';

/// Detects check, including the "flying general" special rule.
class AttackDetector {
  AttackDetector._();

  /// Whether any piece belonging to [attacker] could move to [target] in one
  /// pseudo-legal move (i.e. [target] is under attack). Reuses the same
  /// movement generator as normal move generation, so chariot/cannon/horse
  /// blocking rules apply identically here.
  static bool isSquareAttackedBy(Board board, Side attacker, BoardPoint target) {
    for (final entry in board.occupiedSquares) {
      if (entry.value.side != attacker) continue;
      if (pseudoLegalDestinations(board, entry.key).contains(target)) return true;
    }
    return false;
  }

  /// The "flying general" rule: the two generals may never face each other
  /// on the same open column with no piece between them. This is checked as
  /// whole-board validation (not a per-piece movement rule) because neither
  /// general can normally attack at range - this facing condition is itself
  /// the illegal state, and counts as delivering check to whichever side is
  /// about to move into or already sits in it.
  static bool isFlyingGeneralFacing(Board board) {
    final red = board.findGeneral(Side.red);
    final black = board.findGeneral(Side.black);
    if (red == null || black == null) return false;
    if (red.col != black.col) return false;
    final col = red.col;
    final lowRow = red.row < black.row ? red.row : black.row;
    final highRow = red.row < black.row ? black.row : red.row;
    for (var r = lowRow + 1; r < highRow; r++) {
      if (board.pieceAt(BoardPoint(r, col)) != null) return false;
    }
    return true;
  }

  static bool isGeneralInCheck(Board board, Side side) {
    final general = board.findGeneral(side);
    if (general == null) return false;
    if (isSquareAttackedBy(board, side.opponent, general)) return true;
    if (isFlyingGeneralFacing(board)) return true;
    return false;
  }
}
