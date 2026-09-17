import { Router } from 'express';
import { Redis } from 'ioredis';
import { z } from 'zod';

import { requireAuth } from '../auth/authMiddleware';
import { roomJoinRateLimiter } from '../middleware/roomJoinRateLimiter';
import { timeControlFromRequest } from '../rooms/clock';
import { RoomFullError, RoomManager, RoomNotFoundError } from '../rooms/roomManager';

const createRoomSchema = z.object({
  timeControlMinutes: z.number().positive().max(180).optional(),
  incrementSeconds: z.number().nonnegative().max(60).optional(),
});

const joinRoomSchema = z.object({
  pin: z.string().length(6),
});

/**
 * `POST /api/v1/rooms` and `POST /api/v1/rooms/join` per
 * docs/ARCHITECTURE.md section 5. Gameplay itself happens over the
 * WebSocket gateway (`websocket/roomsGateway.ts`) once a room is active -
 * these routes only create/join the room record.
 */
export function createRoomsRouter(roomManager: RoomManager, redis: Redis): Router {
  const router = Router();

  router.post('/rooms', requireAuth, async (req, res, next) => {
    try {
      const body = createRoomSchema.parse(req.body);
      const timeControl = timeControlFromRequest(body.timeControlMinutes, body.incrementSeconds);
      const state = await roomManager.createRoom({ id: req.user!.sub, username: req.user!.username }, timeControl);
      res.json({
        roomId: state.roomId,
        pin: state.pin,
        // Placeholder scheme - real deep-link handling (universal/app
        // links) is out of scope for this pass; see docs/ARCHITECTURE.md.
        shareLink: `vuaco://join?pin=${state.pin}`,
        state,
      });
    } catch (err) {
      next(err);
    }
  });

  router.post('/rooms/join', requireAuth, roomJoinRateLimiter(redis), async (req, res, next) => {
    try {
      const body = joinRoomSchema.parse(req.body);
      const state = await roomManager.joinRoom(body.pin, { id: req.user!.sub, username: req.user!.username });
      res.json({ state });
    } catch (err) {
      if (err instanceof RoomNotFoundError) {
        res.status(404).json({ error: 'room_not_found', message: err.message });
        return;
      }
      if (err instanceof RoomFullError) {
        res.status(409).json({ error: 'room_full', message: err.message });
        return;
      }
      next(err);
    }
  });

  router.get('/rooms/:id', requireAuth, (req, res) => {
    try {
      const state = roomManager.getSnapshot(req.params.id!);
      res.json({ state });
    } catch (err) {
      if (err instanceof RoomNotFoundError) {
        res.status(404).json({ error: 'room_not_found', message: err.message });
        return;
      }
      throw err;
    }
  });

  return router;
}
