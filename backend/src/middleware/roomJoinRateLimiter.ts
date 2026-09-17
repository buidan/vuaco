import { NextFunction, Request, Response } from 'express';
import { Redis } from 'ioredis';

import { config } from '../config';

/**
 * Redis-backed limiter specifically for room-PIN join attempts, per
 * docs/ARCHITECTURE.md section 7 ("Room PINs must be rate-limited on join
 * attempts (Redis-backed) to prevent brute-forcing 6-digit codes"). A
 * fixed window keyed by user + IP - simple, and sufficient to make
 * brute-forcing a 6-character PIN space impractical without needing a
 * sliding-window algorithm for this phase.
 */
export function roomJoinRateLimiter(redis: Redis) {
  return async (req: Request, res: Response, next: NextFunction): Promise<void> => {
    const userId = req.user?.sub ?? 'anonymous';
    const key = `room-join-attempts:${userId}:${req.ip}`;

    try {
      const count = await redis.incr(key);
      if (count === 1) {
        await redis.expire(key, config.roomJoinRateLimitWindowSeconds);
      }
      if (count > config.roomJoinRateLimitMax) {
        res.status(429).json({
          error: 'too_many_attempts',
          message: 'Too many room join attempts - please wait before trying again.',
        });
        return;
      }
    } catch {
      // If Redis is unreachable, fail open rather than blocking all room
      // joins on an infra hiccup - the PIN space plus auth requirement
      // still bound the risk in the meantime.
    }
    next();
  };
}
