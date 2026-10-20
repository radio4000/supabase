-- Index tracks.tags so tag filters (`tags && '{jazz}'`, PostgREST `tags=ov.{...}`)
-- don't scan the whole tracks table. Rare or missing tags were a full Seq Scan.
create index if not exists "tracks_tags_gin" on "public"."tracks" using "gin" ("tags");
