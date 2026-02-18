-- Adds "slug" from (channel). This is our main view for tracks
create or replace view "public"."channel_tracks"
with
  ("security_invoker" = 'on') as
select
  "tracks"."id",
  "tracks"."created_at",
  "tracks"."updated_at",
  "tracks"."url",
  "tracks"."discogs_url",
  "tracks"."title",
  "tracks"."description",
  "tracks"."tags",
  "tracks"."mentions",
  "tracks"."fts",
  "channels"."slug",
  "tracks"."duration",
  "tracks"."playback_error",
  "tracks"."provider",
  "tracks"."media_id"
from
  (
    (
      "public"."tracks"
      join "public"."channel_track" on (("tracks"."id" = "channel_track"."track_id"))
    )
    join "public"."channels" on (("channels"."id" = "channel_track"."channel_id"))
  );

-- Adds (at least) two fields to channels: track_count and latest_track_at.
create or replace view "public"."channels_with_tracks"
with
  ("security_invoker" = 'on') as
select
  "c"."id",
  "c"."name",
  "c"."slug",
  "c"."description",
  "c"."url",
  "c"."image",
  "c"."longitude",
  "c"."latitude",
  "c"."coordinates",
  "c"."favorites",
  "c"."followers",
  "c"."firebase_id",
  "c"."fts",
  "c"."created_at",
  "c"."updated_at",
  COALESCE("tc"."track_count", (0)::bigint) as "track_count",
  "tc"."latest_track_at"
from
  (
    "public"."channels" "c"
    left join (
      select
        "channel_track"."channel_id",
        "count" (*) as "track_count",
        "max" ("channel_track"."created_at") as "latest_track_at"
      from
        "public"."channel_track"
      group by
        "channel_track"."channel_id"
    ) "tc" on (("c"."id" = "tc"."channel_id"))
  );

-- Gets random channels (with count + latest)
create or replace view "public"."random_channels_with_tracks"
with
  ("security_invoker" = 'on') as
select *
from
  "public"."channels_with_tracks"
order by
  ("random" ());
