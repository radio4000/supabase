-- this adds a `track_count` field 
create or replace view channels_with_tracks
	with (security_invoker=on)
	as

SELECT 
  c.*,
  COALESCE(tc.track_count, 0) AS track_count
FROM channels c
LEFT JOIN (
  SELECT channel_id, count(*) AS track_count 
  FROM channel_track 
  GROUP BY channel_id
) tc ON c.id = tc.channel_id
