import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/models/board.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/piece.dart';
import 'package:vuaco/domain/models/piece_type.dart';
import 'package:vuaco/domain/models/side.dart';
import 'package:vuaco/domain/rules/piece_moves.dart';

void main() {
  group('General', () {
    test('moves one point orthogonally within an empty palace', () {
      final board = Board.empty().withPieceAt(const BoardPoint(1, 4), const Piece(PieceType.general, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(1, 4));
      expect(moves.toSet(), {
        const BoardPoint(0, 4),
        const BoardPoint(2, 4),
        const BoardPoint(1, 3),
        const BoardPoint(1, 5),
      });
    });

    test('cannot step diagonally', () {
      final board = Board.empty().withPieceAt(const BoardPoint(1, 4), const Piece(PieceType.general, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(1, 4));
      expect(moves.contains(const BoardPoint(2, 5)), isFalse);
    });

    test('cannot leave the palace under any circumstance', () {
      final board = Board.empty().withPieceAt(const BoardPoint(2, 4), const Piece(PieceType.general, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(2, 4));
      // Row 3 would leave the Red palace (rows 0-2).
      expect(moves.contains(const BoardPoint(3, 4)), isFalse);
    });

    test('cannot step off the palace file at its corner', () {
      final board = Board.empty().withPieceAt(const BoardPoint(0, 3), const Piece(PieceType.general, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(0, 3));
      // Col 2 would leave the palace columns (3-5).
      expect(moves.contains(const BoardPoint(0, 2)), isFalse);
      expect(moves.toSet(), {const BoardPoint(0, 4), const BoardPoint(1, 3)});
    });

    test('Black general is confined to its own palace (rows 7-9)', () {
      final board = Board.empty().withPieceAt(const BoardPoint(9, 4), const Piece(PieceType.general, Side.black));
      final moves = pseudoLegalDestinations(board, const BoardPoint(9, 4));
      expect(moves.contains(const BoardPoint(6, 4)), isFalse);
      expect(moves.toSet(), {const BoardPoint(8, 4), const BoardPoint(9, 3), const BoardPoint(9, 5)});
    });

    test('can capture an adjacent enemy piece inside the palace', () {
      var board = Board.empty().withPieceAt(const BoardPoint(1, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(1, 3), const Piece(PieceType.advisor, Side.black));
      final moves = pseudoLegalDestinations(board, const BoardPoint(1, 4));
      expect(moves.contains(const BoardPoint(1, 3)), isTrue);
    });

    test('cannot capture a friendly piece', () {
      var board = Board.empty().withPieceAt(const BoardPoint(1, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(1, 3), const Piece(PieceType.advisor, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(1, 4));
      expect(moves.contains(const BoardPoint(1, 3)), isFalse);
    });
  });
}
