import '../../domain/engine/xiangqi_engine.dart';
import '../../domain/models/board.dart';
import '../../domain/models/chess_clock.dart';
import '../../domain/models/side.dart';

/// Boundary between the presentation layer and the domain engine. Phase 1
/// only ever hands back a fresh in-memory game, but keeping this as an
/// injectable interface means a later phase can add a repository that
/// resumes a saved game or hydrates from a multiplayer session without
/// touching the presentation layer.
abstract class PassAndPlayRepository {
  /// [board]/[sideToMove] let Phase 5's board-setup flow start a game from
  /// a pasted FEN or a hand-edited position instead of the standard
  /// starting position.
  XiangqiEngine createNewGame({ClockConfig clockConfig, Board? board, Side sideToMove});
}

class InMemoryPassAndPlayRepository implements PassAndPlayRepository {
  @override
  XiangqiEngine createNewGame({
    ClockConfig clockConfig = const ClockConfig(),
    Board? board,
    Side sideToMove = Side.red,
  }) =>
      XiangqiEngine(clockConfig: clockConfig, board: board, sideToMove: sideToMove);
}
