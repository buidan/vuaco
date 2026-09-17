/** One candidate line from a MultiPV analysis, ranked 1 = best. */
export interface AnalysisLine {
  multiPv: number;
  depth: number;
  scoreType: 'cp' | 'mate';
  /** Centipawns if scoreType is 'cp', moves-to-mate if 'mate'. Positive favors the side to move. */
  scoreValue: number;
  /** Principal variation in UCI coordinate notation (e.g. "e3e4"), best move first. */
  pvMoves: string[];
}

export interface AnalysisResult {
  bestMove: string | null;
  ponder?: string;
  depthReached: number;
  /** Ascending by multiPv rank (1 first). */
  lines: AnalysisLine[];
}

export interface AnalyzeOptions {
  multiPv: number;
  depth: number;
  timeoutMs: number;
}
