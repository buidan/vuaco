import 'dotenv/config';

function envInt(name: string, fallback: number): number {
  const raw = process.env[name];
  if (!raw) return fallback;
  const parsed = Number.parseInt(raw, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function envBool(name: string, fallback: boolean): boolean {
  const raw = process.env[name];
  if (raw === undefined) return fallback;
  return raw === '1' || raw.toLowerCase() === 'true';
}

export const config = {
  env: process.env.NODE_ENV ?? 'development',
  port: envInt('PORT', 3000),

  postgresUrl: process.env.DATABASE_URL ?? 'postgres://vuaco:vuaco@localhost:5433/vuaco',
  redisUrl: process.env.REDIS_URL ?? 'redis://localhost:6380',

  // GPL isolation: this path points at Pikafish's own, unmodified, GPL-3.0
  // binary, invoked as a separate OS process over the UCI stdio protocol.
  // Our TypeScript never links against it - see backend/README.md.
  pikafishBinPath: process.env.PIKAFISH_BIN_PATH ?? '/opt/pikafish/pikafish',
  pikafishWorkingDir: process.env.PIKAFISH_CWD ?? '/opt/pikafish',
  pikafishPoolSize: envInt('PIKAFISH_POOL_SIZE', 2),
  pikafishThreads: envInt('PIKAFISH_THREADS', 1),
  pikafishHashMb: envInt('PIKAFISH_HASH_MB', 64),
  pikafishDefaultDepth: envInt('PIKAFISH_DEFAULT_DEPTH', 14),
  pikafishMaxDepth: envInt('PIKAFISH_MAX_DEPTH', 24),
  pikafishAnalysisTimeoutMs: envInt('PIKAFISH_ANALYSIS_TIMEOUT_MS', 15_000),

  corsOrigin: process.env.CORS_ORIGIN ?? '*',
  rateLimitWindowMs: envInt('RATE_LIMIT_WINDOW_MS', 60_000),
  rateLimitMax: envInt('RATE_LIMIT_MAX', 60),

  logPretty: envBool('LOG_PRETTY', process.env.NODE_ENV !== 'production'),

  // Phase 4: guest-only auth (no passwords) - see backend/README.md for why
  // this is deliberately minimal. Must be overridden in any shared/deployed
  // environment; the fallback is fine for solo local dev only.
  jwtSecret: process.env.JWT_SECRET ?? 'dev-only-insecure-secret-change-me',
  jwtExpiresIn: process.env.JWT_EXPIRES_IN ?? '30d',

  roomPinLength: envInt('ROOM_PIN_LENGTH', 6),
  roomJoinRateLimitWindowSeconds: envInt('ROOM_JOIN_RATE_LIMIT_WINDOW_SECONDS', 300),
  roomJoinRateLimitMax: envInt('ROOM_JOIN_RATE_LIMIT_MAX', 10),

  // Clock-tick granularity for enforcing multiplayer time controls.
  clockTickIntervalMs: envInt('CLOCK_TICK_INTERVAL_MS', 1000),
};

export type AppConfig = typeof config;
