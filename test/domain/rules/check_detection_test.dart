import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/models/board.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/piece.dart';
import 'package:vuaco/domain/models/piece_type.dart';
import 'package:vuaco/domain/models/side.dart';
import 'package:vuaco/domain/rules/attack_detector.dart';

void main() {
  group('Check detection per piece type', () {
    test('chariot delivers check along an open file', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(0, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(5, 4), const Piece(PieceType.chariot, Side.black));
      expect(AttackDetector.isGeneralInCheck(board, Side.red), isTrue);
    });

    test('cannon delivers check only when exactly one screen piece separates it from the general', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(0, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(5, 4), const Piece(PieceType.cannon, Side.black));
      // No screen yet: this is a slide, not a check (destination occupied by
      // the general blocks a same-side non-capturing slide anyway, and a
      // cannon capture needs a screen).
      expect(AttackDetector.isGeneralInCheck(board, Side.red), isFalse);
      board = board.withPieceAt(const BoardPoint(2, 4), const Piece(PieceType.soldier, Side.red));
      expect(AttackDetector.isGeneralInCheck(board, Side.red), isTrue);
    });

    test('horse delivers check in its L-shape, respecting leg-blocking', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(2, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(0, 3), const Piece(PieceType.horse, Side.black));
      expect(AttackDetector.isGeneralInCheck(board, Side.red), isTrue);

      // Blocking the leg removes the check.
      board = board.withPieceAt(const BoardPoint(1, 3), const Piece(PieceType.soldier, Side.red));
      expect(AttackDetector.isGeneralInCheck(board, Side.red), isFalse);
    });

    test('soldier delivers check one step forward', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(2, 4), const Piece(PieceType.general, Side.red));
      // Black advances toward decreasing rows, so a soldier at row 3 steps
      // forward to row 2, landing on the general.
      board = board.withPieceAt(const BoardPoint(3, 4), const Piece(PieceType.soldier, Side.black));
      expect(AttackDetector.isGeneralInCheck(board, Side.red), isTrue);
    });

    test('flying-general facing counts as delivering check', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(0, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(9, 4), const Piece(PieceType.general, Side.black));
      expect(AttackDetector.isGeneralInCheck(board, Side.red), isTrue);
      expect(AttackDetector.isGeneralInCheck(board, Side.black), isTrue);
    });

    test('advisor can never deliver check - it cannot leave its own palace', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(2, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(1, 3), const Piece(PieceType.advisor, Side.black));
      expect(AttackDetector.isGeneralInCheck(board, Side.red), isFalse);
    });

    test('elephant can never deliver check - it cannot cross the river into the enemy palace', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(2, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(4, 6), const Piece(PieceType.elephant, Side.black));
      expect(AttackDetector.isGeneralInCheck(board, Side.red), isFalse);
    });
  });
}
