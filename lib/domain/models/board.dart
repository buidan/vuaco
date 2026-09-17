import '../rules/board_geometry.dart';
import 'board_point.dart';
import 'piece.dart';
import 'piece_type.dart';
import 'side.dart';

/// Immutable snapshot of every piece's position. All mutating-looking
/// operations return a new [Board] rather than modifying this one, so a
/// [Board] can safely be stashed in move history for undo/redo.
class Board {
  final List<List<Piece?>> _grid; // _grid[row][col]

  Board._(this._grid);

  factory Board.empty() => Board._(List.generate(
        BoardGeometry.rows,
        (_) => List<Piece?>.filled(BoardGeometry.columns, null),
      ));

  /// Builds a board from a raw row-major grid (defensively copied).
  factory Board.fromGrid(List<List<Piece?>> grid) {
    if (grid.length != BoardGeometry.rows) {
      throw ArgumentError('Expected ${BoardGeometry.rows} rows, got ${grid.length}');
    }
    return Board._(List<List<Piece?>>.generate(
      BoardGeometry.rows,
      (r) {
        if (grid[r].length != BoardGeometry.columns) {
          throw ArgumentError(
              'Row $r expected ${BoardGeometry.columns} columns, got ${grid[r].length}');
        }
        return List<Piece?>.of(grid[r]);
      },
    ));
  }

  /// The standard Xiangqi starting position.
  factory Board.initial() {
    final grid = List.generate(
      BoardGeometry.rows,
      (_) => List<Piece?>.filled(BoardGeometry.columns, null),
    );
    void put(int row, int col, PieceType type, Side side) =>
        grid[row][col] = Piece(type, side);

    for (final side in Side.values) {
      final backRank = side == Side.red ? 0 : 9;
      final cannonRow = side == Side.red ? 2 : 7;
      final soldierRow = side == Side.red ? 3 : 6;

      put(backRank, 0, PieceType.chariot, side);
      put(backRank, 1, PieceType.horse, side);
      put(backRank, 2, PieceType.elephant, side);
      put(backRank, 3, PieceType.advisor, side);
      put(backRank, 4, PieceType.general, side);
      put(backRank, 5, PieceType.advisor, side);
      put(backRank, 6, PieceType.elephant, side);
      put(backRank, 7, PieceType.horse, side);
      put(backRank, 8, PieceType.chariot, side);

      put(cannonRow, 1, PieceType.cannon, side);
      put(cannonRow, 7, PieceType.cannon, side);

      for (final col in [0, 2, 4, 6, 8]) {
        put(soldierRow, col, PieceType.soldier, side);
      }
    }

    return Board._(grid);
  }

  Piece? pieceAt(BoardPoint p) {
    if (!BoardGeometry.isInsideBoard(p)) return null;
    return _grid[p.row][p.col];
  }

  /// Returns a new board with a single square set (or cleared, if [piece] is
  /// null). Does not validate the move in any way.
  Board withPieceAt(BoardPoint p, Piece? piece) {
    final newGrid = List<List<Piece?>>.generate(
      BoardGeometry.rows,
      (r) => List<Piece?>.of(_grid[r]),
    );
    newGrid[p.row][p.col] = piece;
    return Board._(newGrid);
  }

  /// Returns a new board with the piece at [from] moved to [to], capturing
  /// whatever was at [to]. Purely mechanical - does not validate legality.
  Board applyMove(BoardPoint from, BoardPoint to) {
    final moving = pieceAt(from);
    final newGrid = List<List<Piece?>>.generate(
      BoardGeometry.rows,
      (r) => List<Piece?>.of(_grid[r]),
    );
    newGrid[to.row][to.col] = moving;
    newGrid[from.row][from.col] = null;
    return Board._(newGrid);
  }

  BoardPoint? findGeneral(Side side) {
    for (var r = 0; r < BoardGeometry.rows; r++) {
      for (var c = 0; c < BoardGeometry.columns; c++) {
        final piece = _grid[r][c];
        if (piece != null && piece.type == PieceType.general && piece.side == side) {
          return BoardPoint(r, c);
        }
      }
    }
    return null;
  }

  /// All occupied squares, in row-major order. Used by move/attack
  /// generation and by the FEN encoder.
  Iterable<MapEntry<BoardPoint, Piece>> get occupiedSquares sync* {
    for (var r = 0; r < BoardGeometry.rows; r++) {
      for (var c = 0; c < BoardGeometry.columns; c++) {
        final piece = _grid[r][c];
        if (piece != null) yield MapEntry(BoardPoint(r, c), piece);
      }
    }
  }

  List<BoardPoint> piecesOf(Side side) => [
        for (final entry in occupiedSquares)
          if (entry.value.side == side) entry.key,
      ];
}
