-- Random channels view: returns channels_with_tracks in random order
-- Uses security_invoker to respect RLS policies
create or replace view random_channels_with_tracks
with (security_invoker = on) as
select *
from channels_with_tracks
order by random();
