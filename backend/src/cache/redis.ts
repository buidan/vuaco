import { Redis } from 'ioredis';

import { config } from '../config';

export function createRedisClient(): Redis {
  return new Redis(config.redisUrl, {
    lazyConnect: true,
    maxRetriesPerRequest: 3,
  });
}
