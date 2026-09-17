import cors from 'cors';
import express, { Express } from 'express';
import { Redis } from 'ioredis';
import { Pool } from 'pg';
import pinoHttp from 'pino-http';

import { config } from './config';
import { PikafishPool } from './engine/pikafishPool';
import { errorHandler } from './middleware/errorHandler';
import { apiRateLimiter } from './middleware/rateLimiter';
import { createEngineRouter } from './routes/engine.routes';
import { createHealthRouter } from './routes/health.routes';

export interface AppDependencies {
  db: Pool;
  redis: Redis;
  pool: PikafishPool;
}

export function createApp(deps: AppDependencies): Express {
  const app = express();

  app.use(cors({ origin: config.corsOrigin }));
  app.use(express.json());
  app.use(
    pinoHttp({
      level: config.env === 'test' ? 'silent' : 'info',
      transport: config.logPretty ? { target: 'pino-pretty' } : undefined,
    }),
  );
  app.use('/api/v1', apiRateLimiter);

  app.use('/api/v1', createHealthRouter(deps));
  app.use('/api/v1', createEngineRouter(deps.pool));

  app.use((_req, res) => {
    res.status(404).json({ error: 'not_found' });
  });

  app.use(errorHandler);

  return app;
}
