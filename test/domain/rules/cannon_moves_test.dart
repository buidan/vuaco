import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/models/board.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/piece.dart';
import 'package:vuaco/domain/models/piece_type.dart';
import 'package:vuaco/domain/models/side.dart';
import 'package:vuaco/domain/rules/piece_moves.dart';

void main() {
  group('Cannon', () {
    test('non-capturing moves behave like a chariot: any distance, no jump', () {
      final board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.cannon, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4));
      expect(moves.contains(const BoardPoint(4, 8)), isTrue);
      expect(moves.contains(const BoardPoint(9, 4)), isTrue);
    });

    test('cannot make a non-capturing move onto or past an occupied square', () {
      var board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.cannon, Side.red));
      board = board.withPieceAt(const BoardPoint(4, 6), const Piece(PieceType.soldier, Side.black));
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4));
      expect(moves.contains(const BoardPoint(4, 5)), isTrue); // still clear
      expect(moves.contains(const BoardPoint(4, 6)), isFalse); // landing on the screen itself: illegal
    });

    test('captures by jumping exactly one screen piece, landing immediately beyond it', () {
      var board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.cannon, Side.red));
      board = board.withPieceAt(const BoardPoint(4, 6), const Piece(PieceType.soldier, Side.black)); // screen
      board = board.withPieceAt(const BoardPoint(4, 7), const Piece(PieceType.soldier, Side.black)); // target
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4));
      expect(moves.contains(const BoardPoint(4, 7)), isTrue);
    });

    test('captures by jumping exactly one screen piece even when the target is further away', () {
      var board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.cannon, Side.red));
      board = board.withPieceAt(const BoardPoint(4, 6), const Piece(PieceType.soldier, Side.black)); // screen
      board = board.withPieceAt(const BoardPoint(4, 8), const Piece(PieceType.soldier, Side.black)); // target
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4));
      expect(moves.contains(const BoardPoint(4, 8)), isTrue);
      expect(moves.contains(const BoardPoint(4, 7)), isFalse); // empty square beyond the screen, not a landing spot
    });

    test('cannot capture with zero screens (nothing to jump over)', () {
      var board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.cannon, Side.red));
      board = board.withPieceAt(const BoardPoint(4, 6), const Piece(PieceType.soldier, Side.black));
      // No piece between (4,4) and (4,6): this would be a slide, and (4,6) is occupied,
      // which is exactly the "landing on the screen" case already covered - assert it is
      // NOT treated as a valid jump-capture without an actual screen piece before it.
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4));
      expect(moves.contains(const BoardPoint(4, 6)), isFalse);
    });

    test('cannot capture with two pieces between it and the target (more than one screen)', () {
      var board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.cannon, Side.red));
      board = board.withPieceAt(const BoardPoint(4, 5), const Piece(PieceType.soldier, Side.black)); // screen
      // A second (friendly) piece immediately after the screen blocks the
      // cannon entirely - it cannot land on a friendly square, and it cannot
      // continue past it to a target beyond, because a cannon may only ever
      // jump exactly one piece.
      board = board.withPieceAt(const BoardPoint(4, 6), const Piece(PieceType.soldier, Side.red));
      board = board.withPieceAt(const BoardPoint(4, 7), const Piece(PieceType.soldier, Side.black)); // unreachable target
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4));
      expect(moves.contains(const BoardPoint(4, 6)), isFalse); // friendly piece, cannot land
      expect(moves.contains(const BoardPoint(4, 7)), isFalse); // unreachable: two pieces in the way
    });

    test('the screen piece may belong to either side', () {
      var board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.cannon, Side.red));
      board = board.withPieceAt(const BoardPoint(4, 6), const Piece(PieceType.soldier, Side.red)); // friendly screen
      board = board.withPieceAt(const BoardPoint(4, 7), const Piece(PieceType.soldier, Side.black)); // target
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4));
      expect(moves.contains(const BoardPoint(4, 7)), isTrue);
    });

    test('cannot capture a friendly piece even across a valid screen', () {
      var board = Board.empty().withPieceAt(const BoardPoint(4, 4), const Piece(PieceType.cannon, Side.red));
      board = board.withPieceAt(const BoardPoint(4, 6), const Piece(PieceType.soldier, Side.black));
      board = board.withPieceAt(const BoardPoint(4, 7), const Piece(PieceType.soldier, Side.red));
      final moves = pseudoLegalDestinations(board, const BoardPoint(4, 4));
      expect(moves.contains(const BoardPoint(4, 7)), isFalse);
    });
  });
}
