# Moderation

Admins quarantine spam accounts. A quarantined account's channels and
tracks are hidden and the account is banned. After 30 days it is
purged, unless an admin releases it first. See `*_quarantine.sql`.

## Admins

An admin has `"admin": true` in `app_metadata`. Only the service role
can set it. Set it in the dashboard SQL editor:

```sql
update auth.users
set raw_app_meta_data = raw_app_meta_data || '{"admin": true}'
where id in (select uc.user_id from user_channel uc
             join channels c on c.id = uc.channel_id
             where c.slug in ('oskar', 'ko002'));
```

Remove it with `raw_app_meta_data - 'admin'`. Never use
`user_metadata`: users can write their own, so anyone could become an
admin.

The flag reaches a session at its next token refresh (up to an hour).
Clients read it from the session or call `rpc('is_admin')`. Admins
can't quarantine each other.

List the admins:

```sql
select u.email, array_agg(c.slug) from auth.users u
left join user_channel uc on uc.user_id = u.id
left join channels c on c.id = uc.channel_id
where u.raw_app_meta_data ->> 'admin' = 'true'
group by u.email;
```

## 2FA

To quarantine or release, an admin needs to have verified a code from
an authenticator app (TOTP) in the last 15 minutes. Without one, the
functions answer `admin code needed`. Reading the queue needs no code,
and neither does the SQL editor.

Each admin enrolls once: r4.el (`r4-auth-setup-code`) or
radio4000.com `/account/2fa`. TOTP must be on in the project
(Authentication, Multi-Factor). If an admin loses their phone, remove
their factor in the dashboard and they enroll again.

## Functions

Each takes the slug of one channel and acts on its owner's whole
account, for example `POST /rest/v1/rpc/quarantine_user_by_channel_slug`
with `{"channel_slug": "some-slug"}`.

| Function | What it does |
|---|---|
| `quarantine_user_by_channel_slug` | Stamps `quarantined_at` on the account's channels, which hides them and their tracks from non-admins. Deletes its live broadcast. Bans the account for 30 days. |
| `release_user_by_channel_slug` | Undoes the quarantine and the ban. |
| `quarantined_accounts` | The admins' queue, with each account's slugs and `purge_at`. |
| `purge_quarantined` | Daily at 03:17: bans accounts quarantined for over 30 days for good, and deletes their channels and tracks. |

A banned user gets `user_banned` at sign in. Their row stays in
`auth.users`, so the email can't sign up again. Release clears
`banned_until`, so it also lifts a ban set by hand.

Every quarantine, release and purge goes to `moderation_log`, which
only admins can read.

## Cost

Only `channels` has a hiding policy, and it checks the row's own
`quarantined_at`. Normal reads cost the same however much is in
quarantine. Tracks are hidden through the views, which join channels.
A raw read of `tracks` by id still finds a quarantined track until the
purge.

## Tests

```sh
bunx supabase test db
```
