import express from 'express';
import request from 'supertest';
import { describe, expect, it, vi } from 'vitest';

import { signAuthToken } from '../../src/auth/jwt';
import { errorHandler } from '../../src/middleware/errorHandler';
import { RoomManager } from '../../src/rooms/roomManager';
import { createRoomsRouter } from '../../src/routes/rooms.routes';

function fakeDb() {
  let n = 0;
  return { query: vi.fn(async (sql: string) => (sql.includes('INSERT INTO rooms') ? { rows: [{ id: `room-${++n}` }] } : { rows: [] })) };
}

function fakeRedis() {
  const store = new Map<string, number>();
  return {
    incr: vi.fn(async (key: string) => {
      const next = (store.get(key) ?? 0) + 1;
      store.set(key, next);
      return next;
    }),
    expire: vi.fn(async () => 1),
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
  } as any;
}

function buildApp() {
  const db = fakeDb();
  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  const roomManager = new RoomManager(db as any, 1000);
  const redis = fakeRedis();
  const app = express();
  app.use(express.json());
  app.use('/api/v1', createRoomsRouter(roomManager, redis));
  app.use(errorHandler);
  return { app, redis };
}

const token = signAuthToken({ sub: 'user-1', username: 'Dan' });

describe('rooms routes', () => {
  it('POST /rooms requires auth', async () => {
    const { app } = buildApp();
    const res = await request(app).post('/api/v1/rooms').send({});
    expect(res.status).toBe(401);
  });

  it('POST /rooms creates a room and returns a PIN + share link', async () => {
    const { app } = buildApp();
    const res = await request(app).post('/api/v1/rooms').set('Authorization', `Bearer ${token}`).send({});
    expect(res.status).toBe(200);
    expect(res.body.pin).toHaveLength(6);
    expect(res.body.shareLink).toContain(res.body.pin);
    expect(res.body.state.players.red.userId).toBe('user-1');
  });

  it('POST /rooms/join joins an existing room by PIN', async () => {
    const { app } = buildApp();
    const created = await request(app).post('/api/v1/rooms').set('Authorization', `Bearer ${token}`).send({});
    const guestToken = signAuthToken({ sub: 'user-2', username: 'Eve' });

    const res = await request(app)
      .post('/api/v1/rooms/join')
      .set('Authorization', `Bearer ${guestToken}`)
      .send({ pin: created.body.pin });

    expect(res.status).toBe(200);
    expect(res.body.state.status).toBe('active');
    expect(res.body.state.players.black.userId).toBe('user-2');
  });

  it('POST /rooms/join returns 404 for an unknown PIN', async () => {
    const { app } = buildApp();
    const res = await request(app).post('/api/v1/rooms/join').set('Authorization', `Bearer ${token}`).send({ pin: 'ZZZZZZ' });
    expect(res.status).toBe(404);
  });

  it('POST /rooms/join is rate-limited after too many attempts', async () => {
    const { app, redis } = buildApp();
    for (let i = 0; i < 10; i++) {
      await request(app).post('/api/v1/rooms/join').set('Authorization', `Bearer ${token}`).send({ pin: 'ZZZZZZ' });
    }
    const res = await request(app).post('/api/v1/rooms/join').set('Authorization', `Bearer ${token}`).send({ pin: 'ZZZZZZ' });
    expect(res.status).toBe(429);
    expect(redis.incr).toHaveBeenCalled();
  });

  it('GET /rooms/:id returns the room state', async () => {
    const { app } = buildApp();
    const created = await request(app).post('/api/v1/rooms').set('Authorization', `Bearer ${token}`).send({});
    const res = await request(app).get(`/api/v1/rooms/${created.body.roomId}`).set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(200);
    expect(res.body.state.roomId).toBe(created.body.roomId);
  });

  it('GET /rooms/:id returns 404 for an unknown room', async () => {
    const { app } = buildApp();
    const res = await request(app).get('/api/v1/rooms/nope').set('Authorization', `Bearer ${token}`);
    expect(res.status).toBe(404);
  });
});
