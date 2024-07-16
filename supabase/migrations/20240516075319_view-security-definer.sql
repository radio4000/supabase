-- Re-define the view with security invoker on.
create or replace view channel_tracks
	with (security_invoker=on)
	as
select
	tracks.id,
	tracks.created_at,
	tracks.updated_at,
	tracks.url,
	tracks.discogs_url,
	tracks.title,
	tracks.description,
	tracks.tags,
	tracks.mentions,
	tracks.fts,
	channels.slug
from tracks
join channel_track on tracks.id = channel_track.track_id
join channels on channels.id = channel_track.channel_id;

