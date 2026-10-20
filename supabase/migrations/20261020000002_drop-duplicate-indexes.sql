-- Drop indexes that duplicate a primary key or unique constraint.
-- Each one only costs writes and space; the planner uses the twin.
drop index if exists "public"."channels_slug_index";              -- = channels_slug_key
drop index if exists "public"."channel_track_track_id_idx";       -- = channel_track_track_id_unique
drop index if exists "public"."idx_user_channel_user_channel_id"; -- = user_channel_pkey
