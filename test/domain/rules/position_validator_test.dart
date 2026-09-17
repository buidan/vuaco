import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/models/board.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/piece.dart';
import 'package:vuaco/domain/models/piece_type.dart';
import 'package:vuaco/domain/models/side.dart';
import 'package:vuaco/domain/rules/position_validator.dart';

void main() {
  group('PositionValidator', () {
    test('the standard starting position is playable', () {
      expect(PositionValidator.hasBothGenerals(Board.initial()), isTrue);
      expect(PositionValidator.reasonPositionIsUnplayable(Board.initial()), isNull);
    });

    test('an empty board is missing both generals', () {
      final board = Board.empty();
      expect(PositionValidator.hasBothGenerals(board), isFalse);
      expect(PositionValidator.reasonPositionIsUnplayable(board), contains('Both sides'));
    });

    test('missing only the red general is reported specifically', () {
      final board = Board.empty().withPieceAt(const BoardPoint(9, 4), const Piece(PieceType.general, Side.black));
      expect(PositionValidator.reasonPositionIsUnplayable(board), contains('Red needs'));
    });

    test('missing only the black general is reported specifically', () {
      final board = Board.empty().withPieceAt(const BoardPoint(0, 4), const Piece(PieceType.general, Side.red));
      expect(PositionValidator.reasonPositionIsUnplayable(board), contains('Black needs'));
    });

    test('a sparse but complete position (both generals only) is playable', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(0, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(9, 4), const Piece(PieceType.general, Side.black));
      expect(PositionValidator.reasonPositionIsUnplayable(board), isNull);
    });
  });
}
