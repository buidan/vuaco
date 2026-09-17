import express from 'express';
import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

import { createAuthRouter } from '../../src/routes/auth.routes';
import { verifyAuthToken } from '../../src/auth/jwt';
import { errorHandler } from '../../src/middleware/errorHandler';

function buildApp(dbQuery: ReturnType<typeof vi.fn>) {
  const app = express();
  app.use(express.json());
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  app.use('/api/v1', createAuthRouter({ query: dbQuery } as any));
  app.use(errorHandler);
  return app;
}

describe('POST /api/v1/auth/guest', () => {
  it('creates a guest user and returns a usable token', async () => {
    const dbQuery = vi.fn().mockResolvedValue({ rows: [{ id: 'user-1', username: 'Dan', elo: 1200 }] });
    const res = await request(buildApp(dbQuery)).post('/api/v1/auth/guest').send({ username: 'Dan' });

    expect(res.status).toBe(200);
    expect(res.body.user).toEqual({ id: 'user-1', username: 'Dan', elo: 1200 });
    expect(verifyAuthToken(res.body.token)).toEqual({ sub: 'user-1', username: 'Dan' });
  });

  it('rejects a too-short username', async () => {
    const dbQuery = vi.fn();
    const res = await request(buildApp(dbQuery)).post('/api/v1/auth/guest').send({ username: 'D' });
    expect(res.status).toBe(400);
    expect(dbQuery).not.toHaveBeenCalled();
  });

  it('retries with a suffixed username on a unique-constraint collision', async () => {
    const dbQuery = vi
      .fn()
      .mockRejectedValueOnce({ code: '23505' })
      .mockResolvedValueOnce({ rows: [{ id: 'user-2', username: 'Dan#ab12', elo: 1200 }] });

    const res = await request(buildApp(dbQuery)).post('/api/v1/auth/guest').send({ username: 'Dan' });
    expect(res.status).toBe(200);
    expect(res.body.user.username).toBe('Dan#ab12');
    expect(dbQuery).toHaveBeenCalledTimes(2);
  });
});
