import 'board_point.dart';
import 'piece.dart';

/// A single, already-executed-or-proposed piece movement.
class Move {
  final BoardPoint from;
  final BoardPoint to;
  final Piece movedPiece;
  final Piece? capturedPiece;

  const Move({
    required this.from,
    required this.to,
    required this.movedPiece,
    this.capturedPiece,
  });

  bool get isCapture => capturedPiece != null;

  @override
  String toString() => '$movedPiece $from->$to${isCapture ? ' x$capturedPiece' : ''}';
}
