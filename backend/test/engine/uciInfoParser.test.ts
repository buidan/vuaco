import { describe, expect, it } from 'vitest';

import { parseBestMoveLine, parseInfoLine } from '../../src/engine/uciInfoParser';

describe('parseInfoLine', () => {
  it('parses a full info line with cp score', () => {
    const parsed = parseInfoLine(
      'info depth 12 seldepth 18 multipv 1 score cp 34 nodes 123456 nps 500000 hashfull 200 tbhits 0 time 250 pv e3e4 e6e5 h2e2',
    );
    expect(parsed).toEqual({
      depth: 12,
      seldepth: 18,
      multipv: 1,
      scoreType: 'cp',
      scoreValue: 34,
      nodes: 123456,
      nps: 500000,
      hashfull: 200,
      tbhits: 0,
      time: 250,
      pv: ['e3e4', 'e6e5', 'h2e2'],
    });
  });

  it('parses a mate score', () => {
    const parsed = parseInfoLine('info depth 20 multipv 1 score mate 3 nodes 1 nps 1 time 1 pv a0a1');
    expect(parsed?.scoreType).toBe('mate');
    expect(parsed?.scoreValue).toBe(3);
  });

  it('tolerates a missing hashfull/tbhits and a bound flag', () => {
    const parsed = parseInfoLine('info depth 5 multipv 2 score cp -10 upperbound nodes 1 nps 1 time 1 pv b2b3');
    expect(parsed?.scoreBound).toBe('upperbound');
    expect(parsed?.pv).toEqual(['b2b3']);
  });

  it('parses an "info string" line', () => {
    const parsed = parseInfoLine('info string NNUE evaluation using pikafish.nnue');
    expect(parsed?.string).toBe('NNUE evaluation using pikafish.nnue');
    expect(parsed?.multipv).toBeUndefined();
  });

  it('returns null for a non-info line', () => {
    expect(parseInfoLine('bestmove e3e4')).toBeNull();
  });
});

describe('parseBestMoveLine', () => {
  it('parses a bestmove with ponder', () => {
    expect(parseBestMoveLine('bestmove e3e4 ponder e6e5')).toEqual({ bestMove: 'e3e4', ponder: 'e6e5' });
  });

  it('parses a bestmove with no ponder', () => {
    expect(parseBestMoveLine('bestmove e3e4')).toEqual({ bestMove: 'e3e4', ponder: undefined });
  });

  it('treats "(none)" as no legal move', () => {
    expect(parseBestMoveLine('bestmove (none)')).toEqual({ bestMove: null, ponder: undefined });
  });

  it('returns null for a non-bestmove line', () => {
    expect(parseBestMoveLine('info depth 1')).toBeNull();
  });
});
