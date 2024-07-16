-- Add security_invoker to the two views.

create or replace view orphaned_channels with (security_invoker=on) AS
select * from channels where id not in (select channel_id from user_channel);

create or replace view orphaned_tracks with (security_invoker=on) AS
select * from tracks where id not in (select track_id from channel_track);
