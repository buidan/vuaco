import '../models/board_point.dart';
import '../models/move.dart';

/// Phase 1 uses plain coordinate notation (file a-i, rank 0-9) rather than
/// traditional Chinese piece-relative notation, which needs disambiguation
/// rules (front/middle/back soldier, etc) out of scope for this phase.
class MoveNotation {
  MoveNotation._();

  static String squareLabel(BoardPoint p) => '${String.fromCharCode(97 + p.col)}${p.row}';

  static String forMove(Move move, {bool isCheck = false, bool isCheckmate = false}) {
    final separator = move.isCapture ? 'x' : '-';
    final base = '${squareLabel(move.from)}$separator${squareLabel(move.to)}';
    if (isCheckmate) return '$base#';
    if (isCheck) return '$base+';
    return base;
  }
}
