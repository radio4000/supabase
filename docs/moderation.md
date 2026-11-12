# Moderation

Admins moderate radio4000: they quarantine accounts that fill channels
with spam, and the database deletes them after 30 days unless an admin
releases them. Admins sign in like anyone else; no client needs the
service role key. See the migration `*_quarantine.sql`.

## Admins

An admin is an account with `"admin": true` in its `app_metadata`. Only
the service role can set it (dashboard SQL editor, or `psql`), and
Supabase copies it into the access token. For example, to make the
owners of two channels admins:

```sql
update auth.users
set raw_app_meta_data = raw_app_meta_data || '{"admin": true}'
where id in (select uc.user_id from user_channel uc
             join channels c on c.id = uc.channel_id
             where c.slug in ('oskar', 'ko002'));
```

Remove it with `raw_app_meta_data - 'admin'`. The change reaches a
session at its next token refresh (up to an hour), or at the next sign
in. Clients read the flag from the session, or call `rpc('is_admin')`.

Admins can't quarantine or ban each other: remove the flag first.

Only `app_metadata` counts. Users can write their own `user_metadata`
(`auth.updateUser`), so never check an admin flag there: anyone could
become an admin.

## Quarantine, release, purge

Each function takes the slug of one channel and acts on its owner's
account, all their channels included. Call them as a signed-in admin,
for example `POST /rest/v1/rpc/quarantine_user_by_channel_slug` with
`{"channel_slug": "some-slug"}`.

| Function | What it does |
|---|---|
| `quarantine_user_by_channel_slug` | Sets `accounts.quarantined_at` and `quarantined_by`. Hides the account's channels, their tracks and follows from everyone but admins, and deletes its live broadcast. Bans the account for 30 days: it can't sign in, write, or make a new channel. Deletes nothing else. |
| `release_user_by_channel_slug` | Undoes the quarantine: everything is visible again and the account can sign in. |
| `quarantined_accounts` | The queue of the admins: each quarantined account, its channel slugs, who quarantined it, when, and when it will be purged (`purge_at`). |
| `purge_quarantined` | Daily at 03:17 (`pg_cron`): accounts quarantined for more than 30 days are banned for 4000 years, and their channels and tracks deleted. |
| `ban_user_by_channel_slug`, `ban_user` | Ban at once, as the purge does. |

A banned or quarantined account keeps its row in `auth.users`, so its
email can't sign up again. At sign in, Supabase answers `user_banned`;
clients can say "Your account is under review" with a contact address.

Quarantine is a decision about an account, so it lives on `accounts`,
one row per user. Users can update their own row (theme…) but not
`quarantined_at` (a trigger refuses it), or they could get their own
account deleted.

Quarantine and ban share `auth.users.banned_until`: that is what blocks
sign in and writes. Releasing clears it, so it also lifts a ban set by
other means.

The quarantine period is `quarantine_period()`, 30 days.

## Moderation log

Every quarantine, release, ban and purge adds a row to
`moderation_log`: `admin_id` (null for the service role and the daily
purge), `action`, the account (`user_id`) and its `channel_slugs` at
that moment. Admins can read it; nobody can change it from a client.

## Cost

Hiding quarantined rows runs on every read of channels, tracks and
follows. The policies compute the quarantined ids once per query, as a
hashed set. On 200 000 local tracks, reading a channel's tracks went
from 11 to 15 ms, and counting all tracks from 29 to 64 ms.

## Tests

```sh
bunx supabase start
bunx supabase test db   # supabase/tests/*.test.sql, with pgTAP
```

## Next

User reports and automatic quarantine after enough of them are
designed in r4-svelte's `docs/spam-angel.md`, on top of
`quarantined_at`.
