-- Trigger-maintained stats table to avoid recomputing
-- track_count and latest_track_at on every query.

create table if not exists "public"."channel_stats" (
  "channel_id" "uuid" not null,
  "track_count" bigint not null default 0,
  "latest_track_at" timestamp with time zone,
  constraint "channel_stats_pkey" primary key ("channel_id"),
  constraint "channel_stats_channel_id_fkey" foreign key ("channel_id")
    references "public"."channels" ("id") on delete cascade
);

-- Backfill from current data.
insert into "public"."channel_stats" ("channel_id", "track_count", "latest_track_at")
select
  "channel_id",
  count(*),
  max("created_at")
from "public"."channel_track"
group by "channel_id";

-- RLS: publicly readable, only triggers write.
alter table "public"."channel_stats" enable row level security;

create policy "Channel stats are viewable by everyone"
  on "public"."channel_stats" for select using (true);

-- Trigger function (SECURITY DEFINER to bypass RLS for writes).
create or replace function "public"."update_channel_stats"()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if (TG_OP = 'INSERT') then
    insert into public.channel_stats (channel_id, track_count, latest_track_at)
    values (NEW.channel_id, 1, NEW.created_at)
    on conflict (channel_id) do update set
      track_count = public.channel_stats.track_count + 1,
      latest_track_at = greatest(public.channel_stats.latest_track_at, excluded.latest_track_at);
    return NEW;

  elsif (TG_OP = 'DELETE') then
    update public.channel_stats set
      track_count = track_count - 1,
      latest_track_at = case
        when latest_track_at = OLD.created_at then
          (select max(created_at) from public.channel_track where channel_id = OLD.channel_id)
        else latest_track_at
      end
    where channel_id = OLD.channel_id;
    return OLD;
  end if;
end;
$$;

create trigger "channel_track_stats_insert"
  after insert on "public"."channel_track"
  for each row execute function "public"."update_channel_stats"();

create trigger "channel_track_stats_delete"
  after delete on "public"."channel_track"
  for each row execute function "public"."update_channel_stats"();

-- Rewrite views to join channel_stats instead of re-aggregating.
create or replace view "public"."channels_with_tracks"
with ("security_invoker" = 'on') as
select
  "c".*,
  coalesce("cs"."track_count", (0)::bigint) as "track_count",
  "cs"."latest_track_at"
from
  "public"."channels" "c"
  left join "public"."channel_stats" "cs" on ("c"."id" = "cs"."channel_id");

create or replace view "public"."random_channels_with_tracks"
with ("security_invoker" = 'on') as
select *
from "public"."channels_with_tracks"
order by ("random"());
