import { Router } from 'express';
import { Pool } from 'pg';
import { Redis } from 'ioredis';

import { PikafishPool } from '../engine/pikafishPool';

export interface HealthDependencies {
  db: Pool;
  redis: Redis;
  pool: PikafishPool;
}

export function createHealthRouter({ db, redis, pool }: HealthDependencies): Router {
  const router = Router();

  router.get('/health', async (_req, res) => {
    const checks: Record<string, 'ok' | 'error'> = {};

    try {
      await db.query('SELECT 1');
      checks.database = 'ok';
    } catch {
      checks.database = 'error';
    }

    try {
      await redis.ping();
      checks.redis = 'ok';
    } catch {
      checks.redis = 'error';
    }

    checks.engine = pool.poolSize > 0 ? 'ok' : 'error';

    const healthy = Object.values(checks).every((v) => v === 'ok');
    res.status(healthy ? 200 : 503).json({
      status: healthy ? 'ok' : 'degraded',
      checks,
      engine: { poolSize: pool.poolSize, pending: pool.pendingCount },
    });
  });

  return router;
}
