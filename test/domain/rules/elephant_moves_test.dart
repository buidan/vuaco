import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/models/board.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/piece.dart';
import 'package:vuaco/domain/models/piece_type.dart';
import 'package:vuaco/domain/models/side.dart';
import 'package:vuaco/domain/rules/piece_moves.dart';

void main() {
  group('Elephant', () {
    test('moves exactly two points diagonally when unblocked', () {
      final board = Board.empty().withPieceAt(const BoardPoint(2, 4), const Piece(PieceType.elephant, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(2, 4));
      expect(moves.toSet(), {
        const BoardPoint(0, 2),
        const BoardPoint(0, 6),
        const BoardPoint(4, 2),
        const BoardPoint(4, 6),
      });
    });

    test('is blocked by a piece sitting on the elephant eye', () {
      var board = Board.empty().withPieceAt(const BoardPoint(2, 4), const Piece(PieceType.elephant, Side.red));
      // Eye for the (2,4) -> (4,6) move is (3,5).
      board = board.withPieceAt(const BoardPoint(3, 5), const Piece(PieceType.soldier, Side.black));
      final moves = pseudoLegalDestinations(board, const BoardPoint(2, 4));
      expect(moves.contains(const BoardPoint(4, 6)), isFalse);
      // The other three destinations remain legal since their eyes are clear.
      expect(moves.toSet(), {
        const BoardPoint(0, 2),
        const BoardPoint(0, 6),
        const BoardPoint(4, 2),
      });
    });

    test('cannot cross the river even if the eye is clear', () {
      final board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.elephant, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4));
      // (6,2) and (6,6) would cross into Black's half (row >= 5).
      expect(moves.contains(const BoardPoint(6, 2)), isFalse);
      expect(moves.contains(const BoardPoint(6, 6)), isFalse);
      expect(moves.toSet(), {const BoardPoint(2, 2), const BoardPoint(2, 6)});
    });

    test('Black elephant cannot cross the river southward', () {
      final board = Board.empty().withPieceAt(const BoardPoint(5, 4), const Piece(PieceType.elephant, Side.black));
      final moves = pseudoLegalDestinations(board, const BoardPoint(5, 4));
      expect(moves.contains(const BoardPoint(3, 2)), isFalse);
      expect(moves.contains(const BoardPoint(3, 6)), isFalse);
      expect(moves.toSet(), {const BoardPoint(7, 2), const BoardPoint(7, 6)});
    });
  });
}
