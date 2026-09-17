/// Mirrors the backend's `AnalysisLine`/`AnalysisResult`
/// (backend/src/engine/types.ts) - the client-side shape of a
/// `POST /api/v1/engine/analyze` response. Plain data classes only -
/// decoding the JSON response into these is the data layer's job
/// (`EngineCoachRepository`), keeping this domain model free of any
/// wire-format knowledge.
enum EngineScoreType { centipawns, mate }

class EngineAnalysisLine {
  final int multiPv;
  final int depth;
  final EngineScoreType scoreType;
  final int scoreValue;

  /// UCI coordinate moves (e.g. "e3e4"), best move first.
  final List<String> pvMoves;

  const EngineAnalysisLine({
    required this.multiPv,
    required this.depth,
    required this.scoreType,
    required this.scoreValue,
    required this.pvMoves,
  });

  /// A single monotonic scale for comparing this line's score against
  /// another, collapsing mate scores to a magnitude far outside any
  /// realistic centipawn value rather than trying to weigh "mate in 3"
  /// against "+250cp" on the same axis. Used only for blunder-drop math -
  /// not meant for display (display mate scores as "Mate in N").
  int get comparableScore =>
      scoreType == EngineScoreType.centipawns ? scoreValue : (scoreValue > 0 ? 100000 - scoreValue : -100000 - scoreValue);
}

class EngineAnalysisResult {
  final String? bestMove;
  final String? ponder;
  final int depthReached;

  /// Ascending by multiPv rank (1 first).
  final List<EngineAnalysisLine> lines;

  const EngineAnalysisResult({
    required this.bestMove,
    required this.ponder,
    required this.depthReached,
    required this.lines,
  });
}
