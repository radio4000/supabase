-- Tags summary table
-- Incrementally maintained via trigger on tracks table

create table if not exists "public"."tags" (
  "tag" "text" not null,
  "count" integer not null default 0,
  constraint "tags_pkey" primary key ("tag")
);

-- RLS: publicly readable, no direct writes
alter table "public"."tags" enable row level security;

create policy "Tags are viewable by everyone." on "public"."tags" for
select using (true);

-- Trigger function to maintain tag counts
create or replace function "public"."update_tags_counts"() returns "trigger"
  language "plpgsql"
  security definer
  set "search_path" to 'pg_catalog', 'public'
  as $$
declare
  old_tags text[];
  new_tags text[];
begin
  -- Determine old and new arrays (deduplicated)
  if (TG_OP = 'DELETE') then
    select array_agg(distinct t) into old_tags from unnest(coalesce(OLD.tags, '{}')) t;
    new_tags := '{}';
  elsif (TG_OP = 'INSERT') then
    old_tags := '{}';
    select array_agg(distinct t) into new_tags from unnest(coalesce(NEW.tags, '{}')) t;
  else -- UPDATE
    select array_agg(distinct t) into old_tags from unnest(coalesce(OLD.tags, '{}')) t;
    select array_agg(distinct t) into new_tags from unnest(coalesce(NEW.tags, '{}')) t;
  end if;

  old_tags := coalesce(old_tags, '{}');
  new_tags := coalesce(new_tags, '{}');

  -- Early exit if tags unchanged
  if old_tags = new_tags then
    if (TG_OP = 'DELETE') then return OLD; else return NEW; end if;
  end if;

  -- Decrement removed tags
  update tags set count = tags.count - 1
  where tag = any(old_tags) and not (tag = any(new_tags));

  -- Increment added tags
  insert into tags (tag, count)
  select t, 1 from unnest(new_tags) t
  where not (t = any(old_tags))
  on conflict (tag) do update set count = tags.count + 1;

  -- Clean up zero-count rows
  delete from tags where count <= 0 and tag = any(old_tags);

  if (TG_OP = 'DELETE') then
    return OLD;
  else
    return NEW;
  end if;
end;
$$;

-- Fire AFTER so that parse_track_description has already populated tags
create or replace trigger "update_tags_counts"
  after insert or update or delete on "public"."tracks"
  for each row
  execute function "public"."update_tags_counts"();

-- Backfill from existing data (count each tag once per track)
insert into tags (tag, count)
select t, count(*)
from (
  select distinct id, t
  from tracks, unnest(tags) t
  where tags is not null and tags != '{}'
) sub
group by t
on conflict (tag) do update set count = excluded.count;
