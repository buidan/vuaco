-- Phase 4: online multiplayer needs a second player slot on the room, and
-- a way to link the room to the match record created once the game ends.

ALTER TABLE rooms ADD COLUMN IF NOT EXISTS guest_id UUID REFERENCES users (id);
ALTER TABLE rooms ADD COLUMN IF NOT EXISTS match_id UUID REFERENCES matches (id);

-- Rooms are looked up by PIN on every join attempt.
CREATE INDEX IF NOT EXISTS rooms_pin_idx ON rooms (pin);
