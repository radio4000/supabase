ALTER TABLE IF EXISTS public.tracks
ADD COLUMN playback_error TEXT;

COMMENT ON COLUMN public.tracks.playback_error
  IS 'Non-null when last playback attempt failed; may contain provider error message or code';
