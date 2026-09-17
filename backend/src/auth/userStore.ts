import { randomBytes } from 'node:crypto';
import { Pool } from 'pg';

export interface GuestUser {
  id: string;
  username: string;
  elo: number;
}

export class InvalidUsernameError extends Error {}

const POSTGRES_UNIQUE_VIOLATION = '23505';

function sanitizeUsername(raw: string): string {
  const trimmed = raw.trim();
  if (trimmed.length < 2 || trimmed.length > 24) {
    throw new InvalidUsernameError('Username must be between 2 and 24 characters');
  }
  return trimmed;
}

/**
 * Every call creates a brand-new guest user row - deliberately not "log in
 * as an existing username", since there's no password to prove ownership
 * of one (see backend/README.md's auth section). If the requested name is
 * already taken, a short random suffix is appended so it's still unique
 * and still recognizable.
 */
export async function createGuestUser(db: Pool, requestedUsername: string): Promise<GuestUser> {
  const base = sanitizeUsername(requestedUsername);

  for (let attempt = 0; attempt < 5; attempt++) {
    const username = attempt === 0 ? base : `${base}#${randomBytes(2).toString('hex')}`;
    try {
      const result = await db.query<GuestUser>(
        'INSERT INTO users (username) VALUES ($1) RETURNING id, username, elo',
        [username],
      );
      return result.rows[0]!;
    } catch (err) {
      const code = (err as { code?: string }).code;
      if (code === POSTGRES_UNIQUE_VIOLATION && attempt < 4) continue;
      throw err;
    }
  }
  throw new Error('Could not allocate a unique username after several attempts');
}
