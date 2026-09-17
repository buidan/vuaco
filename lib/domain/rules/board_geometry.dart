import '../models/board_point.dart';
import '../models/side.dart';

/// Board dimensions and zone rules (river, palace) shared by every piece's
/// movement generator and by check/attack detection.
///
/// Orientation: Red occupies rows 0-4 (bottom), Black occupies rows 5-9 (top).
/// The river lies between row 4 (Red's side) and row 5 (Black's side).
class BoardGeometry {
  BoardGeometry._();

  static const int columns = 9; // cols 0-8
  static const int rows = 10; // rows 0-9

  static const int redPalaceMinRow = 0;
  static const int redPalaceMaxRow = 2;
  static const int blackPalaceMinRow = 7;
  static const int blackPalaceMaxRow = 9;
  static const int palaceMinCol = 3;
  static const int palaceMaxCol = 5;

  static bool isInsideBoard(BoardPoint p) =>
      p.row >= 0 && p.row < rows && p.col >= 0 && p.col < columns;

  static bool isInsidePalace(Side side, BoardPoint p) {
    if (p.col < palaceMinCol || p.col > palaceMaxCol) return false;
    return side == Side.red
        ? p.row >= redPalaceMinRow && p.row <= redPalaceMaxRow
        : p.row >= blackPalaceMinRow && p.row <= blackPalaceMaxRow;
  }

  /// Red advances toward increasing row numbers; Black advances toward
  /// decreasing row numbers.
  static int forwardStep(Side side) => side == Side.red ? 1 : -1;

  /// Whether a point at [row] lies on the far side of the river from [side]'s
  /// own starting half of the board.
  static bool hasCrossedRiver(Side side, int row) =>
      side == Side.red ? row >= 5 : row <= 4;
}
