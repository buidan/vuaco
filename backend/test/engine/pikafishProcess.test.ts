import { join } from 'node:path';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';

import { PikafishProcess } from '../../src/engine/pikafishProcess';

const FIXTURE = join(__dirname, '..', 'fixtures', 'fakeUciEngine.js');

function makeProcess(): PikafishProcess {
  return new PikafishProcess(0, {
    binPath: process.execPath,
    args: [FIXTURE],
    cwd: __dirname,
    nnuePath: 'unused.nnue',
    threads: 1,
    hashMb: 16,
  });
}

describe('PikafishProcess', () => {
  let proc: PikafishProcess;

  beforeEach(async () => {
    proc = makeProcess();
    await proc.start();
  });

  afterEach(async () => {
    await proc.stop();
  });

  it('completes the UCI handshake', () => {
    expect(proc.isReady).toBe(true);
  });

  it('returns multiPv candidate lines ranked ascending, plus the best move', async () => {
    const result = await proc.analyze('rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1', {
      multiPv: 3,
      depth: 8,
      timeoutMs: 2000,
    });

    expect(result.bestMove).toBe('e3e4');
    expect(result.ponder).toBe('e6e5');
    expect(result.lines).toHaveLength(3);
    expect(result.lines.map((l) => l.multiPv)).toEqual([1, 2, 3]);
    expect(result.lines[0]?.scoreValue).toBe(90);
    expect(result.lines[0]?.pvMoves).toEqual(['e3e4', 'e6e5']);
  });

  it('recovers via "stop" when the engine stalls past the timeout', async () => {
    // The fixture stalls specifically on depth 999, letting us exercise the
    // "send stop, then wait for the resulting bestmove" recovery path
    // through the real public analyze() call.
    const result = await proc.analyze('rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1', {
      multiPv: 1,
      depth: 999,
      timeoutMs: 50,
    });
    expect(result.bestMove).toBe('e3e4');
  });
});
