-- Auto-fill tracks.duration for YouTube tracks, server-side, so auto-radio
-- eligibility (hasAutoRadioCoverage) trends toward full coverage without
-- manual backfilling.
--
-- Shape (all in-database, no edge function):
--   pg_cron 'youtube-duration-fetch'  -> picks <=50 null-duration youtube ids,
--                                        fires one pg_net request to the
--                                        YouTube Data API (videos.list).
--   pg_cron 'youtube-duration-apply'  -> reads completed pg_net responses,
--                                        matches items back BY media_id, fills
--                                        duration. Requested-but-absent ids
--                                        (deleted/private/live) are tombstoned
--                                        to duration = 0 so we stop re-fetching.
--
-- Ownership invariant preserved: every write is fill-if-null (WHERE duration
-- IS NULL). The server never overwrites an owner's duration. duration = 0 is a
-- "checked, unplayable" sentinel -- toAutoTracks already excludes it, and an
-- owner can still overwrite it on play (the client guards on !track.duration).
--
-- Requires a vault secret named 'youtube_api_key' (NOT in this migration).
-- Set it once:  select vault.create_secret('YOUR_KEY', 'youtube_api_key');

create index if not exists "tracks_youtube_missing_duration_idx"
  on "public"."tracks" ("media_id")
  where "provider" = 'youtube' and "duration" is null;

create table if not exists "public"."youtube_duration_fetch" (
  "request_id" bigint primary key,
  "media_ids" text[] not null,
  "requested_at" timestamptz not null default now()
);

alter table "public"."youtube_duration_fetch" enable row level security;

create or replace function "public"."fetch_youtube_durations"(p_chunks int default 1)
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_key text;
  v_ids text[];
  v_url text;
  v_request_id bigint;
  v_fired int := 0;
  i int;
begin
  select decrypted_secret into v_key
  from vault.decrypted_secrets
  where name = 'youtube_api_key';

  if v_key is null then
    raise warning 'fetch_youtube_durations: no vault secret named youtube_api_key';
    return 0;
  end if;

  for i in 1..greatest(p_chunks, 1) loop
    select array_agg(media_id) into v_ids
    from (
      select distinct t.media_id
      from public.tracks t
      where t.provider = 'youtube'
        and t.duration is null
        and t.media_id is not null
        and not exists (
          select 1 from public.youtube_duration_fetch f
          where t.media_id = any (f.media_ids)
        )
      limit 50
    ) s;

    if v_ids is null or array_length(v_ids, 1) is null then
      exit;
    end if;

    v_url := 'https://www.googleapis.com/youtube/v3/videos'
          || '?part=contentDetails&maxResults=50'
          || '&id=' || array_to_string(v_ids, ',')
          || '&key=' || v_key;

    select net.http_get(v_url, timeout_milliseconds => 5000) into v_request_id;

    insert into public.youtube_duration_fetch (request_id, media_ids)
    values (v_request_id, v_ids);

    v_fired := v_fired + 1;
  end loop;

  return v_fired;
end;
$$;

create or replace function "public"."apply_youtube_durations"()
returns int
language plpgsql
security definer
set search_path = ''
as $$
declare
  r record;
  v_status int;
  v_content text;
  v_n int;
  v_applied int := 0;
begin
  for r in
    select request_id, media_ids, requested_at
    from public.youtube_duration_fetch
    order by requested_at
  loop
    select status_code, content into v_status, v_content
    from net._http_response
    where id = r.request_id;

    if not found then
      if r.requested_at < now() - interval '10 minutes' then
        delete from public.youtube_duration_fetch where request_id = r.request_id;
      end if;
      continue;
    end if;

    if v_status = 200 and v_content is not null then
      update public.tracks t
      set duration = greatest(0, floor(extract(epoch from
            ((it->'contentDetails'->>'duration')::interval)))::int)
      from jsonb_array_elements((v_content::jsonb)->'items') as it
      where t.media_id = (it->>'id')
        and t.provider = 'youtube'
        and t.duration is null
        and (it->'contentDetails'->>'duration') ~ '^P';
      get diagnostics v_n = row_count;
      v_applied := v_applied + v_n;

      update public.tracks
      set duration = 0
      where provider = 'youtube'
        and duration is null
        and media_id = any (r.media_ids);
    end if;

    delete from public.youtube_duration_fetch where request_id = r.request_id;
    delete from net._http_response where id = r.request_id;
  end loop;

  return v_applied;
end;
$$;

revoke execute on function "public"."fetch_youtube_durations"(int) from public, anon, authenticated;
revoke execute on function "public"."apply_youtube_durations"() from public, anon, authenticated;

-- Steady state: 50 ids/min ~= 1,440 API units/day (quota is 10,000/day).
-- To drain the initial backlog faster, temporarily bump the fetch job, e.g.:
--   select cron.alter_job((select jobid from cron.job where jobname='youtube-duration-fetch'),
--                          command => 'select public.fetch_youtube_durations(6)');
-- (6 chunks = 300 ids/min ~= 8,640 units/day), then set it back to 1.
select cron.schedule('youtube-duration-fetch', '* * * * *', 'select public.fetch_youtube_durations(1)');
select cron.schedule('youtube-duration-apply', '* * * * *', 'select public.apply_youtube_durations()');
