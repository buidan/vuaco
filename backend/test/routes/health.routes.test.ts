import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

import { createApp } from '../../src/app';

function buildApp(opts: { dbOk: boolean; redisOk: boolean; poolSize: number }) {
  const db = {
    query: opts.dbOk ? vi.fn().mockResolvedValue({ rows: [] }) : vi.fn().mockRejectedValue(new Error('down')),
  };
  const redis = {
    ping: opts.redisOk ? vi.fn().mockResolvedValue('PONG') : vi.fn().mockRejectedValue(new Error('down')),
  };
  const pool = { analyze: vi.fn(), poolSize: opts.poolSize, pendingCount: 0 };

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  return createApp({ db: db as any, redis: redis as any, pool: pool as any });
}

describe('GET /api/v1/health', () => {
  it('reports 200/ok when every dependency is reachable', async () => {
    const app = buildApp({ dbOk: true, redisOk: true, poolSize: 2 });
    const res = await request(app).get('/api/v1/health');
    expect(res.status).toBe(200);
    expect(res.body.status).toBe('ok');
    expect(res.body.checks).toEqual({ database: 'ok', redis: 'ok', engine: 'ok' });
  });

  it('reports 503/degraded when the database is unreachable', async () => {
    const app = buildApp({ dbOk: false, redisOk: true, poolSize: 2 });
    const res = await request(app).get('/api/v1/health');
    expect(res.status).toBe(503);
    expect(res.body.checks.database).toBe('error');
  });

  it('reports the engine check as error when the pool has no workers', async () => {
    const app = buildApp({ dbOk: true, redisOk: true, poolSize: 0 });
    const res = await request(app).get('/api/v1/health');
    expect(res.status).toBe(503);
    expect(res.body.checks.engine).toBe('error');
  });
});
