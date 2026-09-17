import { createServer } from 'node:http';

import { createApp } from './app';
import { createRedisClient } from './cache/redis';
import { config } from './config';
import { createDbPool } from './db/pool';
import { PikafishPool } from './engine/pikafishPool';
import { RoomManager } from './rooms/roomManager';
import { attachSocketServer } from './websocket/socket';

async function main(): Promise<void> {
  const db = createDbPool();
  const redis = createRedisClient();

  const pool = new PikafishPool(config.pikafishPoolSize, {
    binPath: config.pikafishBinPath,
    cwd: config.pikafishWorkingDir,
    nnuePath: `${config.pikafishWorkingDir}/pikafish.nnue`,
    threads: config.pikafishThreads,
    hashMb: config.pikafishHashMb,
  });

  console.log(`Starting ${config.pikafishPoolSize} Pikafish process(es)...`);
  await pool.start();
  console.log('Pikafish pool ready.');

  const roomManager = new RoomManager(db, config.clockTickIntervalMs);
  roomManager.startClockLoop();

  const app = createApp({ db, redis, pool, roomManager });
  const httpServer = createServer(app);
  attachSocketServer(httpServer, config.corsOrigin, roomManager);

  httpServer.listen(config.port, () => {
    console.log(`vuaco backend listening on :${config.port} (${config.env})`);
  });

  const shutdown = async (signal: string) => {
    console.log(`${signal} received, shutting down...`);
    httpServer.close();
    roomManager.stopClockLoop();
    await pool.stop();
    await db.end();
    redis.disconnect();
    process.exit(0);
  };

  process.on('SIGINT', () => void shutdown('SIGINT'));
  process.on('SIGTERM', () => void shutdown('SIGTERM'));
}

main().catch((err) => {
  console.error('Fatal startup error:', err);
  process.exit(1);
});
