import 'board.dart';
import 'game_result.dart';
import 'move.dart';
import 'side.dart';

/// One recorded ply, carrying enough state to support undo/redo without
/// replaying the whole game.
class MoveHistoryEntry {
  final Move move;
  final String notation;
  final bool isCheck;
  final GameResult resultAfter;
  final Board boardBefore;
  final Side sideToMoveBefore;

  const MoveHistoryEntry({
    required this.move,
    required this.notation,
    required this.isCheck,
    required this.resultAfter,
    required this.boardBefore,
    required this.sideToMoveBefore,
  });
}
