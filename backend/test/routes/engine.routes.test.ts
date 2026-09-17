import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

import { createApp } from '../../src/app';
import { AnalysisResult } from '../../src/engine/types';

const START_FEN = 'rnbakabnr/9/1c5c1/p1p1p1p1p/9/9/P1P1P1P1P/1C5C1/9/RNBAKABNR w - - 0 1';

function buildApp(analyzeImpl: (...args: unknown[]) => Promise<AnalysisResult>) {
  const pool = {
    analyze: vi.fn(analyzeImpl),
    poolSize: 2,
    pendingCount: 0,
  };
  const db = { query: vi.fn().mockResolvedValue({ rows: [] }) };
  const redis = { ping: vi.fn().mockResolvedValue('PONG') };

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const app = createApp({ db: db as any, redis: redis as any, pool: pool as any });
  return { app, pool };
}

const CANNED_RESULT: AnalysisResult = {
  bestMove: 'e3e4',
  ponder: 'e6e5',
  depthReached: 14,
  lines: [
    { multiPv: 1, depth: 14, scoreType: 'cp', scoreValue: 32, pvMoves: ['e3e4', 'e6e5'] },
    { multiPv: 2, depth: 14, scoreType: 'cp', scoreValue: 18, pvMoves: ['h2e2'] },
  ],
};

describe('POST /api/v1/engine/analyze', () => {
  it('returns the pool\'s analysis for a well-formed request', async () => {
    const { app, pool } = buildApp(async () => CANNED_RESULT);

    const res = await request(app).post('/api/v1/engine/analyze').send({ fen: START_FEN, multiPv: 2 });

    expect(res.status).toBe(200);
    expect(res.body).toEqual(CANNED_RESULT);
    expect(pool.analyze).toHaveBeenCalledWith(START_FEN, expect.objectContaining({ multiPv: 2 }));
  });

  it('defaults multiPv to 3 when not provided', async () => {
    const { app, pool } = buildApp(async () => CANNED_RESULT);
    await request(app).post('/api/v1/engine/analyze').send({ fen: START_FEN });
    expect(pool.analyze).toHaveBeenCalledWith(START_FEN, expect.objectContaining({ multiPv: 3 }));
  });

  it('rejects a malformed FEN with 400', async () => {
    const { app } = buildApp(async () => CANNED_RESULT);
    const res = await request(app).post('/api/v1/engine/analyze').send({ fen: 'not-a-fen' });
    expect(res.status).toBe(400);
    expect(res.body.error).toBe('invalid_request');
  });

  it('rejects a missing fen field with 400', async () => {
    const { app } = buildApp(async () => CANNED_RESULT);
    const res = await request(app).post('/api/v1/engine/analyze').send({});
    expect(res.status).toBe(400);
  });

  it('maps an engine timeout to 504', async () => {
    const { app } = buildApp(async () => {
      throw new Error('Pikafish process #0 timed out after 15000ms');
    });
    const res = await request(app).post('/api/v1/engine/analyze').send({ fen: START_FEN });
    expect(res.status).toBe(504);
    expect(res.body.error).toBe('engine_timeout');
  });
});
