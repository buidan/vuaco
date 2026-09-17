import '../models/board.dart';
import '../models/side.dart';

/// Sanity checks for a hand-edited or imported position (Phase 5's board
/// setup flow), distinct from move legality - a position can consist
/// entirely of legally-placed pieces and still be unplayable (e.g. missing
/// a general, which `AttackDetector`/`LegalMoveGenerator` assume exists).
class PositionValidator {
  PositionValidator._();

  static bool hasBothGenerals(Board board) =>
      board.findGeneral(Side.red) != null && board.findGeneral(Side.black) != null;

  /// A short, user-facing reason the position can't be played yet, or null
  /// if it's ready to go. Only checks what the rules engine actually
  /// depends on existing - it does not enforce standard piece counts or
  /// symmetry, which are legitimate to deviate from.
  static String? reasonPositionIsUnplayable(Board board) {
    final hasRedGeneral = board.findGeneral(Side.red) != null;
    final hasBlackGeneral = board.findGeneral(Side.black) != null;
    if (!hasRedGeneral && !hasBlackGeneral) return 'Both sides need a general on the board.';
    if (!hasRedGeneral) return "Red needs a general on the board.";
    if (!hasBlackGeneral) return 'Black needs a general on the board.';
    return null;
  }
}
