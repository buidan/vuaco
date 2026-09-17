import { Router } from 'express';
import { Pool } from 'pg';
import { z } from 'zod';

import { InvalidUsernameError, createGuestUser } from '../auth/userStore';
import { signAuthToken } from '../auth/jwt';

const guestRequestSchema = z.object({
  username: z.string().min(2).max(24),
});

/**
 * `POST /api/v1/auth/guest` - the only auth flow this phase implements.
 * Always creates a fresh guest user (see userStore.ts for why) and returns
 * a long-lived JWT identifying them. No password, no refresh flow - a
 * later phase can add real accounts without touching how rooms/sockets
 * consume the token (they only care about { sub, username }).
 */
export function createAuthRouter(db: Pool): Router {
  const router = Router();

  router.post('/auth/guest', async (req, res, next) => {
    try {
      const body = guestRequestSchema.parse(req.body);
      const user = await createGuestUser(db, body.username);
      const token = signAuthToken({ sub: user.id, username: user.username });
      res.json({ token, user });
    } catch (err) {
      if (err instanceof InvalidUsernameError) {
        res.status(400).json({ error: 'invalid_username', message: err.message });
        return;
      }
      next(err);
    }
  });

  return router;
}
