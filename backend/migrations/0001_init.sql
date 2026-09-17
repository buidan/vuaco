-- Phase 2 skeleton schema, per docs/ARCHITECTURE.md section 6 ("Data Model").
-- Expand with real columns/constraints as each later phase needs them
-- (auth in particular is still TBD - see ARCHITECTURE.md section 3).

CREATE TABLE IF NOT EXISTS users (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username    TEXT NOT NULL UNIQUE,
    elo         INTEGER NOT NULL DEFAULT 1200,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS matches (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    player_red_id   UUID REFERENCES users (id),
    player_black_id UUID REFERENCES users (id),
    result          TEXT,
    move_history    JSONB NOT NULL DEFAULT '[]'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS rooms (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pin             TEXT NOT NULL UNIQUE,
    host_id         UUID REFERENCES users (id),
    status          TEXT NOT NULL DEFAULT 'waiting',
    timer_settings  JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
