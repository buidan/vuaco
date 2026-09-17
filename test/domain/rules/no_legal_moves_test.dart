import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/engine/xiangqi_engine.dart';
import 'package:vuaco/domain/models/board.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/game_result.dart';
import 'package:vuaco/domain/models/piece.dart';
import 'package:vuaco/domain/models/piece_type.dart';
import 'package:vuaco/domain/models/side.dart';

void main() {
  test(
    'a player with no legal moves loses even when not currently in check '
    '(Xiangqi has no stalemate draw)',
    () {
      // Red's general at (1,4) is NOT currently attacked, but every square it
      // could step to is covered by a black chariot, and it has no piece to
      // block or capture with. Red has zero legal moves while not in check.
      var board = Board.empty();
      board = board.withPieceAt(const BoardPoint(1, 4), const Piece(PieceType.general, Side.red));
      board = board.withPieceAt(const BoardPoint(0, 0), const Piece(PieceType.chariot, Side.black)); // guards (0,4)
      board = board.withPieceAt(const BoardPoint(2, 8), const Piece(PieceType.chariot, Side.black)); // guards (2,4)
      board = board.withPieceAt(const BoardPoint(8, 3), const Piece(PieceType.chariot, Side.black)); // guards (1,3)
      board = board.withPieceAt(const BoardPoint(8, 5), const Piece(PieceType.chariot, Side.black)); // guards (1,5)

      final engine = XiangqiEngine(board: board, sideToMove: Side.red);

      expect(engine.isInCheck(Side.red), isFalse);
      expect(engine.allLegalMoves, isEmpty);
      expect(engine.result.isOngoing, isFalse);
      expect(engine.result.winner, Side.black);
      expect(engine.result.reason, GameEndReason.noLegalMoves);
    },
  );
}
