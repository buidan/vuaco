import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/models/board.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/piece.dart';
import 'package:vuaco/domain/models/piece_type.dart';
import 'package:vuaco/domain/models/side.dart';
import 'package:vuaco/domain/rules/attack_detector.dart';
import 'package:vuaco/domain/rules/legal_move_generator.dart';

void main() {
  group('Flying general rule', () {
    test('AttackDetector.isFlyingGeneralFacing detects an open, unobstructed column', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(0, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(9, 4), const Piece(PieceType.general, Side.black));
      expect(AttackDetector.isFlyingGeneralFacing(board), isTrue);
    });

    test('is not triggered when any piece blocks the column between the generals', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(0, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(9, 4), const Piece(PieceType.general, Side.black));
      board = board.withPieceAt(const BoardPoint(5, 4), const Piece(PieceType.soldier, Side.red));
      expect(AttackDetector.isFlyingGeneralFacing(board), isFalse);
    });

    test('is not triggered when the generals are on different columns', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(0, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(9, 3), const Piece(PieceType.general, Side.black));
      expect(AttackDetector.isFlyingGeneralFacing(board), isFalse);
    });

    test('scenario 1: moving the general itself onto the enemy general\'s open column is illegal', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(1, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(8, 3), const Piece(PieceType.general, Side.black));
      // Column 3 is otherwise completely empty between the two generals.
      final legalMoves = LegalMoveGenerator.legalDestinationsFrom(board, const BoardPoint(1, 4), Side.red);
      // (1,3) is a normal one-step palace move for the general, but it would
      // put both generals on column 3 with nothing between them.
      expect(legalMoves.contains(const BoardPoint(1, 3)), isFalse);
      // Its other one-step palace moves remain legal.
      expect(legalMoves.contains(const BoardPoint(0, 4)), isTrue);
    });

    test('scenario 2: moving a piece away that was screening the generals is illegal', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(0, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(9, 4), const Piece(PieceType.general, Side.black));
      board = board.withPieceAt(const BoardPoint(5, 4), const Piece(PieceType.chariot, Side.red));
      final legalMoves = LegalMoveGenerator.legalDestinationsFrom(board, const BoardPoint(5, 4), Side.red);
      // Sliding off column 4 would open a clear file between the two generals.
      expect(legalMoves.contains(const BoardPoint(5, 0)), isFalse);
      expect(legalMoves.contains(const BoardPoint(5, 8)), isFalse);
      // Staying on column 4 (still screening) remains legal.
      expect(legalMoves.contains(const BoardPoint(3, 4)), isTrue);
    });
  });
}
