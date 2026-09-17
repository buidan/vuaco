import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/models/board.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/piece.dart';
import 'package:vuaco/domain/models/piece_type.dart';
import 'package:vuaco/domain/models/side.dart';
import 'package:vuaco/domain/rules/piece_moves.dart';

void main() {
  group('Soldier', () {
    test('Red soldier before the river can only step forward (increasing row)', () {
      final board = Board.empty().withPieceAt(const BoardPoint(3, 4), const Piece(PieceType.soldier, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(3, 4));
      expect(moves.toSet(), {const BoardPoint(4, 4)});
    });

    test('Red soldier cannot move sideways before crossing the river', () {
      final board = Board.empty().withPieceAt(const BoardPoint(3, 4), const Piece(PieceType.soldier, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(3, 4));
      expect(moves.contains(const BoardPoint(3, 3)), isFalse);
      expect(moves.contains(const BoardPoint(3, 5)), isFalse);
    });

    test('Red soldier can move sideways after crossing the river', () {
      final board = Board.empty().withPieceAt(const BoardPoint(5, 4), const Piece(PieceType.soldier, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(5, 4));
      expect(moves.toSet(), {
        const BoardPoint(6, 4),
        const BoardPoint(5, 3),
        const BoardPoint(5, 5),
      });
    });

    test('soldier never moves backward, even after crossing the river', () {
      final board = Board.empty().withPieceAt(const BoardPoint(5, 4), const Piece(PieceType.soldier, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(5, 4));
      expect(moves.contains(const BoardPoint(4, 4)), isFalse);
    });

    test('Black soldier advances toward decreasing rows', () {
      final board = Board.empty().withPieceAt(const BoardPoint(6, 4), const Piece(PieceType.soldier, Side.black));
      final moves = pseudoLegalDestinations(board, const BoardPoint(6, 4));
      expect(moves.toSet(), {const BoardPoint(5, 4)});
    });

    test('Black soldier gains sideways moves after crossing its river boundary', () {
      final board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.soldier, Side.black));
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4));
      expect(moves.toSet(), {
        const BoardPoint(3, 4),
        const BoardPoint(4, 3),
        const BoardPoint(4, 5),
      });
    });

    test('soldier cannot move diagonally', () {
      final board = Board.empty().withPieceAt(const BoardPoint(5, 4), const Piece(PieceType.soldier, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(5, 4));
      expect(moves.contains(const BoardPoint(6, 5)), isFalse);
    });
  });
}
