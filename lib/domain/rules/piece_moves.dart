import '../models/board.dart';
import '../models/board_point.dart';
import '../models/piece_type.dart';
import '../models/side.dart';
import 'board_geometry.dart';

const List<(int, int)> _orthogonalDirections = [(1, 0), (-1, 0), (0, 1), (0, -1)];
const List<(int, int)> _diagonalDirections = [(1, 1), (1, -1), (-1, 1), (-1, -1)];
const List<(int, int)> _elephantDirections = [(2, 2), (2, -2), (-2, 2), (-2, -2)];
const List<(int, int)> _horseDirections = [
  (1, 2), (1, -2), (-1, 2), (-1, -2),
  (2, 1), (2, -1), (-2, 1), (-2, -1),
];

/// A square can be landed on if it is empty, or if it holds an enemy piece
/// (i.e. a capture). Landing on one's own piece is never legal.
bool _canLandOn(Board board, Side side, BoardPoint p) {
  final occupant = board.pieceAt(p);
  return occupant == null || occupant.side != side;
}

/// Pseudo-legal destinations for the piece at [from]: obeys that piece's own
/// movement shape, blocking, and zone rules (palace, river), and never lands
/// on a friendly piece - but does NOT check whether the move would leave the
/// mover's own general in check. That filtering happens one layer up, in
/// `LegalMoveGenerator`, because it requires simulating the move against the
/// whole board.
List<BoardPoint> pseudoLegalDestinations(Board board, BoardPoint from) {
  final piece = board.pieceAt(from);
  if (piece == null) return const [];
  return switch (piece.type) {
    PieceType.general => _generalMoves(board, from, piece.side),
    PieceType.advisor => _advisorMoves(board, from, piece.side),
    PieceType.elephant => _elephantMoves(board, from, piece.side),
    PieceType.horse => _horseMoves(board, from, piece.side),
    PieceType.chariot => _slidingMoves(board, from, piece.side, _orthogonalDirections),
    PieceType.cannon => _cannonMoves(board, from, piece.side),
    PieceType.soldier => _soldierMoves(board, from, piece.side),
  };
}

List<BoardPoint> _generalMoves(Board board, BoardPoint from, Side side) {
  final moves = <BoardPoint>[];
  for (final (dr, dc) in _orthogonalDirections) {
    final dest = from.translate(dr, dc);
    if (!BoardGeometry.isInsidePalace(side, dest)) continue;
    if (_canLandOn(board, side, dest)) moves.add(dest);
  }
  return moves;
}

List<BoardPoint> _advisorMoves(Board board, BoardPoint from, Side side) {
  final moves = <BoardPoint>[];
  for (final (dr, dc) in _diagonalDirections) {
    final dest = from.translate(dr, dc);
    if (!BoardGeometry.isInsidePalace(side, dest)) continue;
    if (_canLandOn(board, side, dest)) moves.add(dest);
  }
  return moves;
}

List<BoardPoint> _elephantMoves(Board board, BoardPoint from, Side side) {
  final moves = <BoardPoint>[];
  for (final (dr, dc) in _elephantDirections) {
    final dest = from.translate(dr, dc);
    if (!BoardGeometry.isInsideBoard(dest)) continue;
    // The elephant can never cross the river, regardless of blocking.
    if (BoardGeometry.hasCrossedRiver(side, dest.row)) continue;
    final eye = from.translate(dr ~/ 2, dc ~/ 2);
    if (board.pieceAt(eye) != null) continue; // blocked at the elephant eye
    if (_canLandOn(board, side, dest)) moves.add(dest);
  }
  return moves;
}

List<BoardPoint> _horseMoves(Board board, BoardPoint from, Side side) {
  final moves = <BoardPoint>[];
  for (final (dr, dc) in _horseDirections) {
    final dest = from.translate(dr, dc);
    if (!BoardGeometry.isInsideBoard(dest)) continue;
    // The "leg" is the orthogonal square along the longer axis of the L.
    final leg = dr.abs() == 2
        ? from.translate(dr ~/ 2, 0)
        : from.translate(0, dc ~/ 2);
    if (board.pieceAt(leg) != null) continue; // blocked at the horse leg
    if (_canLandOn(board, side, dest)) moves.add(dest);
  }
  return moves;
}

List<BoardPoint> _slidingMoves(
  Board board,
  BoardPoint from,
  Side side,
  List<(int, int)> directions,
) {
  final moves = <BoardPoint>[];
  for (final (dr, dc) in directions) {
    var step = 1;
    while (true) {
      final dest = from.translate(dr * step, dc * step);
      if (!BoardGeometry.isInsideBoard(dest)) break;
      final occupant = board.pieceAt(dest);
      if (occupant == null) {
        moves.add(dest);
      } else {
        if (occupant.side != side) moves.add(dest); // capture
        break; // blocked either way past this point
      }
      step++;
    }
  }
  return moves;
}

List<BoardPoint> _cannonMoves(Board board, BoardPoint from, Side side) {
  final moves = <BoardPoint>[];
  for (final (dr, dc) in _orthogonalDirections) {
    var step = 1;
    var screenFound = false;
    while (true) {
      final dest = from.translate(dr * step, dc * step);
      if (!BoardGeometry.isInsideBoard(dest)) break;
      final occupant = board.pieceAt(dest);
      if (!screenFound) {
        if (occupant == null) {
          moves.add(dest); // ordinary slide, no jump yet
        } else {
          screenFound = true; // this piece becomes the screen
        }
      } else {
        if (occupant != null) {
          if (occupant.side != side) moves.add(dest); // capture over the screen
          break; // a second piece always blocks further travel
        }
      }
      step++;
    }
  }
  return moves;
}

List<BoardPoint> _soldierMoves(Board board, BoardPoint from, Side side) {
  final moves = <BoardPoint>[];
  final forward = from.translate(BoardGeometry.forwardStep(side), 0);
  if (BoardGeometry.isInsideBoard(forward) && _canLandOn(board, side, forward)) {
    moves.add(forward);
  }
  if (BoardGeometry.hasCrossedRiver(side, from.row)) {
    for (final dc in [1, -1]) {
      final dest = from.translate(0, dc);
      if (BoardGeometry.isInsideBoard(dest) && _canLandOn(board, side, dest)) {
        moves.add(dest);
      }
    }
  }
  return moves;
}
