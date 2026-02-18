-- Add decks jsonb column for multi-deck broadcast snapshots.
-- Stop relying on flat single-deck columns (track_id, etc.).
-- Client code writes full deck state to `decks`; old columns kept for now.

-- 1. Add decks column
ALTER TABLE broadcast ADD COLUMN IF NOT EXISTS decks jsonb;

-- 2. Drop FK on track_id (if it exists), then make it nullable
ALTER TABLE broadcast DROP CONSTRAINT IF EXISTS broadcast_track_id_fkey;
ALTER TABLE broadcast ALTER COLUMN track_id DROP NOT NULL;
