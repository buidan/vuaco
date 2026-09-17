import 'package:flutter_test/flutter_test.dart';
import 'package:vuaco/domain/engine/xiangqi_engine.dart';
import 'package:vuaco/domain/models/board_point.dart';
import 'package:vuaco/domain/models/illegal_move_reason.dart';
import 'package:vuaco/domain/models/move_validation_result.dart';
import 'package:vuaco/domain/models/side.dart';

void main() {
  group('XiangqiEngine', () {
    test('starts with Red to move on the standard position', () {
      final engine = XiangqiEngine();
      expect(engine.sideToMove, Side.red);
      expect(engine.result.isOngoing, isTrue);
      expect(engine.history, isEmpty);
    });

    test('executes a legal move and flips the turn', () {
      final engine = XiangqiEngine();
      final result = engine.tryMove(const BoardPoint(3, 4), const BoardPoint(4, 4)); // central soldier advances
      expect(result, isA<LegalMove>());
      expect(engine.sideToMove, Side.black);
      expect(engine.history, hasLength(1));
      expect(engine.board.pieceAt(const BoardPoint(4, 4)), isNotNull);
      expect(engine.board.pieceAt(const BoardPoint(3, 4)), isNull);
    });

    test('rejects moving a piece that is not the current side\'s turn', () {
      final engine = XiangqiEngine();
      final result = engine.tryMove(const BoardPoint(6, 4), const BoardPoint(5, 4)); // Black soldier, Red to move
      expect(result, isA<IllegalMove>());
      expect((result as IllegalMove).reason, IllegalMoveReason.notYourTurn);
      expect(engine.sideToMove, Side.red); // unchanged
    });

    test('rejects a move with no piece at the source', () {
      final engine = XiangqiEngine();
      final result = engine.tryMove(const BoardPoint(5, 5), const BoardPoint(5, 6));
      expect(result, isA<IllegalMove>());
      expect((result as IllegalMove).reason, IllegalMoveReason.noPieceAtSource);
    });

    test('rejects a geometrically illegal move for the piece', () {
      final engine = XiangqiEngine();
      // Chariot at (0,0) cannot move diagonally.
      final result = engine.tryMove(const BoardPoint(0, 0), const BoardPoint(1, 1));
      expect(result, isA<IllegalMove>());
      expect((result as IllegalMove).reason, IllegalMoveReason.illegalPieceMovement);
    });

    test('undo restores the exact prior board, turn, and result', () {
      final engine = XiangqiEngine();
      final fenBefore = engine.toFen();
      engine.tryMove(const BoardPoint(3, 4), const BoardPoint(4, 4));
      expect(engine.canUndo, isTrue);

      final undone = engine.undo();
      expect(undone, isTrue);
      expect(engine.sideToMove, Side.red);
      expect(engine.history, isEmpty);
      expect(FenCodecEquivalent(engine.toFen()), FenCodecEquivalent(fenBefore));
    });

    test('redo re-applies an undone move', () {
      final engine = XiangqiEngine();
      engine.tryMove(const BoardPoint(3, 4), const BoardPoint(4, 4));
      final fenAfterMove = engine.toFen();
      engine.undo();
      expect(engine.canRedo, isTrue);

      final redone = engine.redo();
      expect(redone, isTrue);
      expect(engine.sideToMove, Side.black);
      expect(engine.history, hasLength(1));
      expect(engine.toFen(), fenAfterMove);
    });

    test('making a new move after an undo clears the redo stack', () {
      final engine = XiangqiEngine();
      engine.tryMove(const BoardPoint(3, 4), const BoardPoint(4, 4));
      engine.undo();
      engine.tryMove(const BoardPoint(3, 2), const BoardPoint(4, 2));
      expect(engine.canRedo, isFalse);
    });

    test('undo is a no-op on a fresh game', () {
      final engine = XiangqiEngine();
      expect(engine.undo(), isFalse);
    });

    test('no moves are accepted once the game has ended', () {
      // Red's general at (0,3) is already checkmated by the two black
      // chariots (same corner-mate shape as in checkmate_test.dart).
      final engine = XiangqiEngine.fromFen('3rr4/9/9/9/9/9/9/9/9/3K5 w - - 0 1');
      expect(engine.result.isOngoing, isFalse);

      final result = engine.tryMove(const BoardPoint(0, 3), const BoardPoint(0, 4));
      expect(result, isA<IllegalMove>());
      expect((result as IllegalMove).reason, IllegalMoveReason.gameAlreadyOver);
    });
  });
}

/// Wraps a FEN string so test failures print a readable diff instead of a
/// giant opaque string comparison failure.
class FenCodecEquivalent {
  final String fen;
  const FenCodecEquivalent(this.fen);

  @override
  bool operator ==(Object other) => other is FenCodecEquivalent && other.fen == fen;

  @override
  int get hashCode => fen.hashCode;

  @override
  String toString() => fen;
}
