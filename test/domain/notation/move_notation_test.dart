import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/move.dart';
import 'package:vuaco/domain/models/piece.dart';
import 'package:vuaco/domain/models/piece_type.dart';
import 'package:vuaco/domain/models/side.dart';
import 'package:vuaco/domain/notation/move_notation.dart';

void main() {
  group('MoveNotation.squareLabel / parseSquare', () {
    test('round-trips every square on the board', () {
      for (var row = 0; row < 10; row++) {
        for (var col = 0; col < 9; col++) {
          final point = BoardPoint(row, col);
          expect(MoveNotation.parseSquare(MoveNotation.squareLabel(point)), point);
        }
      }
    });

    test('matches the UCI/Pikafish convention (file a-i, rank 0-9)', () {
      expect(MoveNotation.squareLabel(const BoardPoint(3, 4)), 'e3');
      expect(MoveNotation.parseSquare('e3'), const BoardPoint(3, 4));
    });
  });

  group('MoveNotation.parseUciMove', () {
    test('parses a four-character coordinate move', () {
      final (from, to) = MoveNotation.parseUciMove('e3e4');
      expect(from, const BoardPoint(3, 4));
      expect(to, const BoardPoint(4, 4));
    });

    test('round-trips against forMove\'s own output for a non-capture', () {
      final move = Move(
        from: const BoardPoint(3, 4),
        to: const BoardPoint(4, 4),
        movedPiece: const Piece(PieceType.soldier, Side.red),
      );
      final notation = MoveNotation.forMove(move); // "e3-e4"
      final uci = notation.replaceAll('-', ''); // engines omit the separator
      expect(MoveNotation.parseUciMove(uci), (move.from, move.to));
    });

    test('rejects a move string of the wrong length', () {
      expect(() => MoveNotation.parseUciMove('e3e'), throwsFormatException);
      expect(() => MoveNotation.parseUciMove('e3e44'), throwsFormatException);
    });
  });
}
