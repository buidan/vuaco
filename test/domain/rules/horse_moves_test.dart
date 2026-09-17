import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/models/board.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/piece.dart';
import 'package:vuaco/domain/models/piece_type.dart';
import 'package:vuaco/domain/models/side.dart';
import 'package:vuaco/domain/rules/piece_moves.dart';

void main() {
  group('Horse', () {
    test('moves in an L-shape from the center of the board', () {
      final board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.horse, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4));
      expect(moves.toSet(), {
        const BoardPoint(5, 6), const BoardPoint(5, 2),
        const BoardPoint(3, 6), const BoardPoint(3, 2),
        const BoardPoint(6, 5), const BoardPoint(6, 3),
        const BoardPoint(2, 5), const BoardPoint(2, 3),
      });
    });

    test('is blocked by a piece on the horse leg (long axis), even though the destination is empty', () {
      var board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.horse, Side.red));
      // Leg for the (4,4) -> (6,5) and (4,4) -> (6,3) moves is (5,4).
      board = board.withPieceAt(const BoardPoint(5, 4), const Piece(PieceType.soldier, Side.black));
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4));
      expect(moves.contains(const BoardPoint(6, 5)), isFalse);
      expect(moves.contains(const BoardPoint(6, 3)), isFalse);
      // Moves along the other axis (leg at (4,5) or (4,3)) are unaffected.
      expect(moves.contains(const BoardPoint(5, 6)), isTrue);
      expect(moves.contains(const BoardPoint(3, 6)), isTrue);
    });

    test('a piece on the destination square itself does not block the leg check', () {
      // Regression guard: leg-blocking must check the orthogonal leg square,
      // not the diagonal destination square, which is a distinct point.
      var board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.horse, Side.red));
      board = board.withPieceAt(const BoardPoint(6, 5), const Piece(PieceType.soldier, Side.black));
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4));
      expect(moves.contains(const BoardPoint(6, 5)), isTrue); // capture, not blocked
    });

    test('can capture an enemy piece at the destination', () {
      var board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.horse, Side.red));
      board = board.withPieceAt(const BoardPoint(2, 3), const Piece(PieceType.soldier, Side.black));
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4));
      expect(moves.contains(const BoardPoint(2, 3)), isTrue);
    });

    test('cannot capture a friendly piece', () {
      var board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.horse, Side.red));
      board = board.withPieceAt(const BoardPoint(2, 3), const Piece(PieceType.soldier, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4));
      expect(moves.contains(const BoardPoint(2, 3)), isFalse);
    });

    test('moves are clipped at the board edge', () {
      final board = Board.empty().withPieceAt(const BoardPoint(0, 0), const Piece(PieceType.horse, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(0, 0));
      expect(moves.toSet(), {const BoardPoint(1, 2), const BoardPoint(2, 1)});
    });
  });
}
