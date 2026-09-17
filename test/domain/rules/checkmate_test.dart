import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/engine/xiangqi_engine.dart';
import 'package:vuaco/domain/models/board.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/game_result.dart';
import 'package:vuaco/domain/models/piece.dart';
import 'package:vuaco/domain/models/piece_type.dart';
import 'package:vuaco/domain/models/side.dart';

/// These are hand-constructed minimal positions (not taken from real games)
/// chosen so the mating pattern is unambiguous to verify by eye.
void main() {
  group('Checkmate detection', () {
    test('corner mate: two chariots cover both of the general\'s escape squares', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(0, 3), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(9, 3), const Piece(PieceType.chariot, Side.black));
      board = board.withPieceAt(const BoardPoint(9, 4), const Piece(PieceType.chariot, Side.black));

      final engine = XiangqiEngine(board: board, sideToMove: Side.red);

      expect(engine.isInCheck(Side.red), isTrue);
      expect(engine.result.isOngoing, isFalse);
      expect(engine.result.winner, Side.black);
      expect(engine.result.reason, GameEndReason.checkmate);
    });

    test('horse mate: general boxed in by its own pieces, check is unblockable and uncapturable', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(1, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(0, 4), const Piece(PieceType.advisor, Side.red));
      board = board.withPieceAt(const BoardPoint(2, 4), const Piece(PieceType.advisor, Side.red));
      // Advisors here (rather than soldiers) because every diagonal square
      // they could otherwise reach is either outside the palace or occupied
      // by another red piece - so none of them can step onto the horse's
      // leg square (2,5) and block the check.
      board = board.withPieceAt(const BoardPoint(1, 3), const Piece(PieceType.advisor, Side.red));
      board = board.withPieceAt(const BoardPoint(1, 5), const Piece(PieceType.advisor, Side.red));
      board = board.withPieceAt(const BoardPoint(3, 5), const Piece(PieceType.horse, Side.black));

      final engine = XiangqiEngine(board: board, sideToMove: Side.red);

      expect(engine.isInCheck(Side.red), isTrue);
      expect(engine.result.isOngoing, isFalse);
      expect(engine.result.winner, Side.black);
      expect(engine.result.reason, GameEndReason.checkmate);
    });

    test('is not checkmate if the general can capture the checking piece', () {
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(0, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(1, 4), const Piece(PieceType.soldier, Side.black));

      final engine = XiangqiEngine(board: board, sideToMove: Side.red);

      expect(engine.isInCheck(Side.red), isTrue);
      expect(engine.result.isOngoing, isTrue);
    });
  });
}
