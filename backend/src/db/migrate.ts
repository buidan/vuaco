import { readFileSync, readdirSync } from 'node:fs';
import { join } from 'node:path';

import { createDbPool } from './pool';

const MIGRATIONS_DIR = join(__dirname, '..', '..', 'migrations');

/** Minimal sequential migration runner: applies every `migrations/*.sql`
 * file (in filename order) that isn't already recorded in
 * `schema_migrations`. No down-migrations - Phase 2 skeleton only. */
async function migrate(): Promise<void> {
  const pool = createDbPool();
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        filename    TEXT PRIMARY KEY,
        applied_at  TIMESTAMPTZ NOT NULL DEFAULT now()
      )
    `);

    const applied = new Set(
      (await pool.query<{ filename: string }>('SELECT filename FROM schema_migrations')).rows.map(
        (row) => row.filename,
      ),
    );

    const files = readdirSync(MIGRATIONS_DIR)
      .filter((name) => name.endsWith('.sql'))
      .sort();

    for (const file of files) {
      if (applied.has(file)) continue;
      const sql = readFileSync(join(MIGRATIONS_DIR, file), 'utf8');
      console.log(`Applying migration ${file}...`);
      await pool.query('BEGIN');
      try {
        await pool.query(sql);
        await pool.query('INSERT INTO schema_migrations (filename) VALUES ($1)', [file]);
        await pool.query('COMMIT');
      } catch (err) {
        await pool.query('ROLLBACK');
        throw err;
      }
    }

    console.log('Migrations up to date.');
  } finally {
    await pool.end();
  }
}

if (require.main === module) {
  migrate().catch((err) => {
    console.error(err);
    process.exit(1);
  });
}
