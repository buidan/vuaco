import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/models/board.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/piece.dart';
import 'package:vuaco/domain/models/piece_type.dart';
import 'package:vuaco/domain/models/side.dart';
import 'package:vuaco/domain/rules/piece_moves.dart';

void main() {
  group('Chariot', () {
    test('slides any distance along an empty rank and file', () {
      final board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.chariot, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4)).toSet();
      for (var r = 0; r < 10; r++) {
        if (r != 4) expect(moves.contains(BoardPoint(r, 4)), isTrue, reason: 'row $r');
      }
      for (var c = 0; c < 9; c++) {
        if (c != 4) expect(moves.contains(BoardPoint(4, c)), isTrue, reason: 'col $c');
      }
    });

    test('is blocked by the first piece in its path and stops before a friendly piece', () {
      var board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.chariot, Side.red));
      board = board.withPieceAt(const BoardPoint(4, 6), const Piece(PieceType.soldier, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4));
      expect(moves.contains(const BoardPoint(4, 5)), isTrue);
      expect(moves.contains(const BoardPoint(4, 6)), isFalse); // friendly, cannot land
      expect(moves.contains(const BoardPoint(4, 7)), isFalse); // beyond the blocker
    });

    test('captures the first enemy piece in its path but cannot jump over it', () {
      var board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.chariot, Side.red));
      board = board.withPieceAt(const BoardPoint(4, 6), const Piece(PieceType.soldier, Side.black));
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4));
      expect(moves.contains(const BoardPoint(4, 5)), isTrue);
      expect(moves.contains(const BoardPoint(4, 6)), isTrue); // capture
      expect(moves.contains(const BoardPoint(4, 7)), isFalse); // beyond the captured piece
    });
  });
}
