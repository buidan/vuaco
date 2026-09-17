import '../../domain/engine/xiangqi_engine.dart';
import '../../domain/models/chess_clock.dart';

/// Boundary between the presentation layer and the domain engine. Phase 1
/// only ever hands back a fresh in-memory game, but keeping this as an
/// injectable interface means a later phase can add a repository that
/// resumes a saved game or hydrates from a multiplayer session without
/// touching the presentation layer.
abstract class PassAndPlayRepository {
  XiangqiEngine createNewGame({ClockConfig clockConfig});
}

class InMemoryPassAndPlayRepository implements PassAndPlayRepository {
  @override
  XiangqiEngine createNewGame({ClockConfig clockConfig = const ClockConfig()}) =>
      XiangqiEngine(clockConfig: clockConfig);
}
