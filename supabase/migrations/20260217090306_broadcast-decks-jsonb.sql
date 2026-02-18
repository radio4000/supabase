-- Add decks jsonb column for multi-deck broadcast snapshots.
-- Stop relying on flat single-deck columns (track_id, etc.).
-- Client code writes full deck state to `decks`; old columns kept for now.

-- 1. Add decks column
ALTER TABLE broadcast ADD COLUMN IF NOT EXISTS decks jsonb;

-- 2. Drop the composite PK (includes track_id which we're making nullable)
ALTER TABLE broadcast DROP CONSTRAINT broadcast_pkey;

-- 3. Use channel_id as the sole PK (already has a unique constraint)
ALTER TABLE broadcast ADD PRIMARY KEY (channel_id);

-- 4. Drop FK on track_id, then make it nullable
ALTER TABLE broadcast DROP CONSTRAINT broadcast_track_id_fkey;
ALTER TABLE broadcast ALTER COLUMN track_id DROP NOT NULL;
