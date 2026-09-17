import { Router } from 'express';
import { z } from 'zod';

import { config } from '../config';
import { PikafishPool } from '../engine/pikafishPool';
import { isPlausibleXiangqiFen } from '../utils/fen';

const analyzeRequestSchema = z.object({
  fen: z.string().refine(isPlausibleXiangqiFen, { message: 'fen is not a well-formed Xiangqi FEN' }),
  multiPv: z.number().int().min(1).max(10).optional(),
  depth: z.number().int().min(1).max(config.pikafishMaxDepth).optional(),
});

/**
 * `POST /api/v1/engine/analyze` per docs/ARCHITECTURE.md section 5: body
 * `{ fen, multiPv }` -> top-N candidate moves with evaluation scores. The
 * client never talks to Pikafish directly - this route (and the pool it
 * calls) is the only thing that does.
 */
export function createEngineRouter(pool: PikafishPool): Router {
  const router = Router();

  router.post('/engine/analyze', async (req, res, next) => {
    try {
      const body = analyzeRequestSchema.parse(req.body);
      const result = await pool.analyze(body.fen, {
        multiPv: body.multiPv ?? 3,
        depth: body.depth ?? config.pikafishDefaultDepth,
        timeoutMs: config.pikafishAnalysisTimeoutMs,
      });
      res.json(result);
    } catch (err) {
      next(err);
    }
  });

  return router;
}
