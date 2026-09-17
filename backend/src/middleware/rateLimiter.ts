import rateLimit from 'express-rate-limit';

import { config } from '../config';

/**
 * Generic IP-based limiter for Phase 2's only real endpoint
 * (`/engine/analyze`), which is the expensive one (spawns a Pikafish
 * search). Room-PIN brute-force protection is a separate, Redis-backed
 * limiter to add in Phase 4 once rooms exist (see
 * docs/ARCHITECTURE.md section 7) - this one is not a substitute for that.
 */
export const apiRateLimiter = rateLimit({
  windowMs: config.rateLimitWindowMs,
  limit: config.rateLimitMax,
  standardHeaders: true,
  legacyHeaders: false,
});
