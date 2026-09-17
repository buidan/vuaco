import { Pool } from 'pg';

import { config } from '../config';

export function createDbPool(): Pool {
  return new Pool({ connectionString: config.postgresUrl });
}
