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

  /// Parses a bare square label like "e3" (no separator) - the format UCI
  /// engines such as Pikafish use, which happens to match [squareLabel]'s
  /// own alphabet (file a-i, rank 0-9).
  static BoardPoint parseSquare(String label) {
    if (label.length < 2) {
      throw FormatException('Invalid square label "$label"');
    }
    final col = label.codeUnitAt(0) - 97; // 'a' = 0
    final row = int.parse(label.substring(1));
    return BoardPoint(row, col);
  }

  /// Parses a UCI coordinate move such as "e3e4" (always exactly two
  /// concatenated square labels - Xiangqi has no promotion suffix).
  static (BoardPoint from, BoardPoint to) parseUciMove(String move) {
    if (move.length != 4) {
      throw FormatException('Invalid UCI move "$move"');
    }
    return (parseSquare(move.substring(0, 2)), parseSquare(move.substring(2, 4)));
  }
}
