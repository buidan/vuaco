import express from 'express';
import request from 'supertest';
import { describe, expect, it } from 'vitest';

import { requireAuth } from '../../src/auth/authMiddleware';
import { signAuthToken } from '../../src/auth/jwt';

function buildApp() {
  const app = express();
  app.get('/protected', requireAuth, (req, res) => {
    res.json({ user: req.user });
  });
  return app;
}

describe('requireAuth', () => {
  it('rejects a request with no Authorization header', async () => {
    const res = await request(buildApp()).get('/protected');
    expect(res.status).toBe(401);
  });

  it('rejects a malformed Authorization header', async () => {
    const res = await request(buildApp()).get('/protected').set('Authorization', 'garbage');
    expect(res.status).toBe(401);
  });

  it('rejects an invalid token', async () => {
    const res = await request(buildApp()).get('/protected').set('Authorization', 'Bearer not-a-token');
    expect(res.status).toBe(401);
  });

  it('attaches the decoded user for a valid token', async () => {
    const token = signAuthToken({ sub: 'user-1', username: 'Dan' });
    const res = await request(buildApp()).get('/protected').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.user).toEqual({ sub: 'user-1', username: 'Dan' });
  });
});
