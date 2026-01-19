-- Ensure a track can belong to only one channel.

alter table public.channel_track
	add constraint channel_track_track_id_unique unique (track_id);
