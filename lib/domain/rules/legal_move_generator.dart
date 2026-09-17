import '../models/board.dart';
import '../models/board_point.dart';
import '../models/move.dart';
import '../models/side.dart';
import 'attack_detector.dart';
import 'piece_moves.dart';

/// Produces fully legal moves: pseudo-legal moves for a piece, with any move
/// filtered out that would leave the mover's own general in check (which, by
/// construction, also covers the flying-general facing condition since
/// [AttackDetector.isGeneralInCheck] checks for it).
class LegalMoveGenerator {
  LegalMoveGenerator._();

  static List<BoardPoint> legalDestinationsFrom(
    Board board,
    BoardPoint from,
    Side sideToMove,
  ) {
    final piece = board.pieceAt(from);
    if (piece == null || piece.side != sideToMove) return const [];
    final pseudoLegal = pseudoLegalDestinations(board, from);
    return pseudoLegal.where((to) {
      final next = board.applyMove(from, to);
      return !AttackDetector.isGeneralInCheck(next, sideToMove);
    }).toList();
  }

  static List<Move> allLegalMoves(Board board, Side sideToMove) {
    final moves = <Move>[];
    for (final entry in board.occupiedSquares) {
      if (entry.value.side != sideToMove) continue;
      for (final to in legalDestinationsFrom(board, entry.key, sideToMove)) {
        moves.add(Move(
          from: entry.key,
          to: to,
          movedPiece: entry.value,
          capturedPiece: board.pieceAt(to),
        ));
      }
    }
    return moves;
  }

  /// Short-circuits as soon as one legal move is found - cheaper than
  /// `allLegalMoves(...).isNotEmpty` for the common "is this checkmate?"
  /// query after every move.
  static bool hasAnyLegalMove(Board board, Side sideToMove) {
    for (final entry in board.occupiedSquares) {
      if (entry.value.side != sideToMove) continue;
      if (legalDestinationsFrom(board, entry.key, sideToMove).isNotEmpty) {
        return true;
      }
    }
    return false;
  }
}
