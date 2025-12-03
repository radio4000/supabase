ALTER TABLE IF EXISTS public.tracks
ADD COLUMN duration INTEGER;

COMMENT ON COLUMN public.tracks.duration
    IS 'Duration of the track in seconds (nullable if unavailable, for exemple when track media is broken)';
