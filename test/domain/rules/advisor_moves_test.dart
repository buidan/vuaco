import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/models/board.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/piece.dart';
import 'package:vuaco/domain/models/piece_type.dart';
import 'package:vuaco/domain/models/side.dart';
import 'package:vuaco/domain/rules/piece_moves.dart';

void main() {
  group('Advisor', () {
    test('moves one point diagonally from the palace center', () {
      final board = Board.empty().withPieceAt(const BoardPoint(1, 4), const Piece(PieceType.advisor, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(1, 4));
      expect(moves.toSet(), {
        const BoardPoint(0, 3),
        const BoardPoint(0, 5),
        const BoardPoint(2, 3),
        const BoardPoint(2, 5),
      });
    });

    test('cannot move orthogonally', () {
      final board = Board.empty().withPieceAt(const BoardPoint(1, 4), const Piece(PieceType.advisor, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(1, 4));
      expect(moves.contains(const BoardPoint(0, 4)), isFalse);
    });

    test('cannot step outside the palace', () {
      final board = Board.empty().withPieceAt(const BoardPoint(0, 3), const Piece(PieceType.advisor, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(0, 3));
      // (1,2) is diagonal but outside the palace columns.
      expect(moves.toSet(), {const BoardPoint(1, 4)});
    });

    test('Black advisor confined to rows 7-9', () {
      final board = Board.empty().withPieceAt(const BoardPoint(9, 4), const Piece(PieceType.advisor, Side.black));
      final moves = pseudoLegalDestinations(board, const BoardPoint(9, 4));
      expect(moves.toSet(), {const BoardPoint(8, 3), const BoardPoint(8, 5)});
    });
  });
}
