/** Loosely-typed, parsed form of one "info ..." UCI line. Fields are only
 * present if the engine included the corresponding token. */
export interface ParsedInfoLine {
  depth?: number;
  seldepth?: number;
  multipv?: number;
  scoreType?: 'cp' | 'mate';
  scoreValue?: number;
  scoreBound?: 'lowerbound' | 'upperbound';
  nodes?: number;
  nps?: number;
  hashfull?: number;
  tbhits?: number;
  time?: number;
  pv?: string[];
  string?: string;
}

const NUMERIC_KEYS = new Set(['depth', 'seldepth', 'multipv', 'nodes', 'nps', 'hashfull', 'tbhits', 'time']);

/**
 * Parses one line of Pikafish/Stockfish-style UCI "info ..." output.
 * Tolerant of engines that omit or reorder optional fields (hashfull,
 * tbhits, WDL, etc) - walks token-by-token rather than matching one fixed
 * regex, since the exact set of fields varies by engine and options.
 */
export function parseInfoLine(line: string): ParsedInfoLine | null {
  const tokens = line.trim().split(/\s+/);
  if (tokens[0] !== 'info') return null;

  const result: ParsedInfoLine = {};
  let i = 1;
  while (i < tokens.length) {
    const key = tokens[i];
    if (key === undefined) break;

    if (NUMERIC_KEYS.has(key)) {
      const value = Number(tokens[i + 1]);
      (result as Record<string, number>)[key] = value;
      i += 2;
      continue;
    }

    if (key === 'score') {
      const kind = tokens[i + 1];
      const value = Number(tokens[i + 2]);
      if (kind === 'cp' || kind === 'mate') {
        result.scoreType = kind;
        result.scoreValue = value;
      }
      i += 3;
      if (tokens[i] === 'lowerbound' || tokens[i] === 'upperbound') {
        result.scoreBound = tokens[i] as 'lowerbound' | 'upperbound';
        i += 1;
      }
      continue;
    }

    if (key === 'pv') {
      result.pv = tokens.slice(i + 1);
      break; // pv always runs to end of line
    }

    if (key === 'string') {
      result.string = tokens.slice(i + 1).join(' ');
      break; // "info string ..." also runs to end of line
    }

    // Unknown/unhandled token (e.g. "currmove", "wdl ..."): skip just the key
    // defensively so a single unexpected field can't desync the rest of the parse.
    i += 1;
  }

  return result;
}

export interface ParsedBestMove {
  bestMove: string | null; // null when the engine reports "(none)"
  ponder?: string;
}

export function parseBestMoveLine(line: string): ParsedBestMove | null {
  const tokens = line.trim().split(/\s+/);
  if (tokens[0] !== 'bestmove') return null;
  const bestMove = tokens[1];
  const ponderIndex = tokens.indexOf('ponder');
  const ponder = ponderIndex >= 0 ? tokens[ponderIndex + 1] : undefined;
  return {
    bestMove: !bestMove || bestMove === '(none)' ? null : bestMove,
    ponder,
  };
}
