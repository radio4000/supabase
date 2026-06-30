# YouTube track durations

Auto-radio only plays channels where most tracks have a `duration` (see `hasAutoRadioCoverage` in the frontend). Two `pg_cron` jobs keep `tracks.duration` filled for YouTube tracks, so coverage grows on its own — no manual backfilling.

Migration: `20260630223325_youtube_duration_backfill.sql`.

## How it works

- `youtube-duration-fetch` (every min) — picks ≤50 null-duration youtube tracks and calls the YouTube Data API (`videos.list`) via `pg_net`.
- `youtube-duration-apply` (every min) — reads the response, matches videos back by `media_id`, and fills `duration` (fill-if-null only — an owner's value is never overwritten).
- Deleted/private/live videos get `duration = 0` (a "checked, unplayable" sentinel) so they stop being re-fetched.

Needs a vault secret named `youtube_api_key`:

```sql
select vault.create_secret('YOUR_KEY', 'youtube_api_key');
```

## Operating

Rate is 50 ids/min ≈ 1,440 API units/day (quota is 10,000/day). To drain a large backlog faster, temporarily bump the fetch job, then revert:

```sql
-- 6 chunks = 300 ids/min ≈ 8,640 units/day
select cron.alter_job((select jobid from cron.job where jobname='youtube-duration-fetch'),
                      command => 'select public.fetch_youtube_durations(6)');
```

Progress:

```sql
select count(*) filter (where duration > 0)    as real,
       count(*) filter (where duration = 0)    as tombstoned,
       count(*) filter (where duration is null) as remaining
from tracks where provider='youtube';
```

Pause: `select cron.unschedule('youtube-duration-fetch');`
