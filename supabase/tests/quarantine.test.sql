-- Admins quarantine and release; quarantined accounts are purged after
-- the quarantine period. Run with: bunx supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(40);

-- a: admin, b: another admin, c: a user, d: a spammer
insert into auth.users (id, email, raw_app_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'admin@example.org', '{"admin": true}'),
  ('00000000-0000-0000-0000-00000000000b', 'admin2@example.org', '{"admin": true}'),
  ('00000000-0000-0000-0000-00000000000c', 'user@example.org', '{}'),
  ('00000000-0000-0000-0000-00000000000d', 'spam@example.org', '{}');

insert into public.channels (id, name, slug) values
  ('10000000-0000-0000-0000-00000000000b', 'Admin', 'admin-radio'),
  ('10000000-0000-0000-0000-00000000000c', 'User', 'user-radio'),
  ('10000000-0000-0000-0000-00000000000d', 'Spam', 'spam-radio'),
  ('10000000-0000-0000-0000-0000000000d2', 'Spam 2', 'spam-radio-2');
insert into public.user_channel (user_id, channel_id) values
  ('00000000-0000-0000-0000-00000000000b', '10000000-0000-0000-0000-00000000000b'),
  ('00000000-0000-0000-0000-00000000000c', '10000000-0000-0000-0000-00000000000c'),
  ('00000000-0000-0000-0000-00000000000d', '10000000-0000-0000-0000-00000000000d'),
  ('00000000-0000-0000-0000-00000000000d', '10000000-0000-0000-0000-0000000000d2');
insert into public.tracks (id, url, title) values
  ('20000000-0000-0000-0000-00000000000c', 'https://www.youtube.com/watch?v=pmpXABDFMyE', 'A song'),
  ('20000000-0000-0000-0000-00000000000d', 'https://example.org/buy-now', 'Buy now');
insert into public.channel_track (user_id, channel_id, track_id) values
  ('00000000-0000-0000-0000-00000000000c', '10000000-0000-0000-0000-00000000000c',
   '20000000-0000-0000-0000-00000000000c'),
  ('00000000-0000-0000-0000-00000000000d', '10000000-0000-0000-0000-00000000000d',
   '20000000-0000-0000-0000-00000000000d');
-- Accounts made before the accounts table have no row.
delete from public.accounts where id = '00000000-0000-0000-0000-00000000000d';
insert into public.followers (follower_id, channel_id) values
  ('10000000-0000-0000-0000-00000000000c', '10000000-0000-0000-0000-00000000000d');

-- Signs in as user ID; the token carries app_metadata, as Supabase's does,
-- and a code just verified (see admin-2fa.test.sql).
create function pg_temp.as_user(id text) returns void language plpgsql as $$
declare
  metadata jsonb;
begin
  reset role;
  select raw_app_meta_data into metadata from auth.users where auth.users.id = as_user.id::uuid;
  perform set_config('request.jwt.claims',
                     json_build_object('sub', id, 'role', 'authenticated', 'app_metadata', metadata,
                                       'aal', 'aal2',
                                       'amr', json_build_array(json_build_object(
                                         'method', 'totp', 'timestamp', extract(epoch from now()))))::text,
                     true);
  perform set_config('role', 'authenticated', true);
end;
$$;
create function pg_temp.as_anon() returns void language sql as $$
  select set_config('role', 'anon', true),
         set_config('request.jwt.claims', '{"role": "anon"}', true);
$$;
create function pg_temp.visible() returns text[] language sql as $$
  select array[
    (select count(*) from public.channels where slug like 'spam-radio%')::text,
    (select count(*) from public.tracks where id = '20000000-0000-0000-0000-00000000000d')::text,
    (select count(*) from public.channel_tracks where slug = 'spam-radio')::text,
    (select count(*) from public.followers where channel_id = '10000000-0000-0000-0000-00000000000d')::text];
$$;

-- Who is an admin
select pg_temp.as_anon();
select is(public.is_admin(), false, 'anon is not an admin');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select is(public.is_admin(), false, 'a user is not an admin');
-- Users write their own user_metadata: it must not make them admins.
select set_config('request.jwt.claims',
  '{"sub": "00000000-0000-0000-0000-00000000000c", "role": "authenticated", "user_metadata": {"admin": true}}', true);
select is(public.is_admin(), false, 'admin in user_metadata is not an admin');
select throws_ok($$ select public.quarantine_user_by_channel_slug('spam-radio') $$,
  'not authorized', 'a user cannot quarantine');
select hasnt_function('public', 'ban_user', 'the immediate ban is gone');
select hasnt_function('public', 'ban_user_by_channel_slug', 'by slug too');
select throws_ok($$ select public.purge_quarantined() $$, '42501', null, 'a user cannot purge');
select throws_ok($$ select public.purge_account('00000000-0000-0000-0000-00000000000d') $$,
  '42501', null, 'a user cannot call the internal functions');
select throws_ok($$ update public.accounts set quarantined_at = now()
                    where id = '00000000-0000-0000-0000-00000000000c' $$,
  'only admins quarantine accounts', 'a user cannot quarantine their own account');
select throws_ok($$ select * from public.quarantined_accounts() $$,
  'not authorized', 'a user cannot read the queue');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select is(public.is_admin(), true, 'an admin is an admin');
select throws_ok($$ select public.quarantine_user_by_channel_slug('admin-radio') $$,
  'cannot moderate an admin', 'an admin cannot quarantine an admin');

-- Quarantine
select pg_temp.as_anon();
select is(pg_temp.visible(), array['2', '1', '1', '1'], 'before, everyone sees the spam');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select lives_ok($$ select public.quarantine_user_by_channel_slug('spam-radio') $$, 'an admin can quarantine');
select is(pg_temp.visible(), array['2', '1', '1', '1'], 'admins still see it');
select throws_ok($$ select public.quarantine_user_by_channel_slug('spam-radio-2') $$,
  'the account of spam-radio-2 is already quarantined', 'quarantining twice says so');
select results_eq(
  $$ select user_id, channel_slugs, quarantined_by, purge_at = quarantined_at + interval '30 days'
     from public.quarantined_accounts() $$,
  $$ values ('00000000-0000-0000-0000-00000000000d'::uuid, array['spam-radio', 'spam-radio-2'],
             '00000000-0000-0000-0000-00000000000a'::uuid, true) $$,
  'admins read the queue');
select pg_temp.as_anon();
select is(pg_temp.visible(), array['0', '0', '0', '0'], 'anon no longer sees any channel of the account');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select is(pg_temp.visible(), array['0', '0', '0', '0'], 'users no longer see it');
select is((select count(*) from public.channels where slug = 'user-radio'), 1::bigint, 'other channels stay');
select is((select count(*) from public.tracks where id = '20000000-0000-0000-0000-00000000000c'), 1::bigint,
  'other tracks stay');
reset role;
select ok((select banned_until between now() + interval '29 days' and now() + interval '31 days'
           from auth.users where id = '00000000-0000-0000-0000-00000000000d'),
  'the account is banned for the quarantine period');
select is((select count(*) from public.tracks where id = '20000000-0000-0000-0000-00000000000d'), 1::bigint,
  'nothing is deleted');

-- The spammer, banned, can't write
select pg_temp.as_user('00000000-0000-0000-0000-00000000000d');
select throws_ok($$ insert into public.channels (name, slug) values ('Again', 'spam-again') $$,
  '42501', null, 'the quarantined account cannot make a new channel');

-- Users still add tracks: a new track is readable before it is linked
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select lives_ok($$ insert into public.tracks (url, title) values ('https://www.youtube.com/watch?v=dQw4w9WgXcQ', 'New') returning id $$,
  'a user can add a track and read it back');

-- Release
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select lives_ok($$ select public.release_user_by_channel_slug('spam-radio-2') $$, 'an admin can release');
select throws_ok($$ select public.release_user_by_channel_slug('spam-radio') $$,
  'the account of spam-radio is not quarantined', 'releasing twice says so');
select pg_temp.as_anon();
select is(pg_temp.visible(), array['2', '1', '1', '1'], 'released channels are visible again');
reset role;
select is((select banned_until from auth.users where id = '00000000-0000-0000-0000-00000000000d'), null,
  'the account is no longer banned');

-- Purge after the period
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');
select public.quarantine_user_by_channel_slug('spam-radio');
reset role;
select is(public.purge_quarantined(), 0, 'a recent quarantine is not purged');
update public.accounts set quarantined_at = now() - interval '31 days'
where id = '00000000-0000-0000-0000-00000000000d';
-- A broadcast row blocks deleting its channel: the purge removes it first.
insert into public.broadcast (channel_id, track_id, track_played_at)
values ('10000000-0000-0000-0000-00000000000d', '20000000-0000-0000-0000-00000000000d', now());
select is(public.purge_quarantined(), 1, 'an old quarantine is purged');
select is(public.purge_quarantined(), 0, 'once');
select is((select count(*) from public.channels where slug like 'spam-radio%'), 0::bigint,
  'the purged channels are deleted');
select is((select count(*) from public.tracks where id = '20000000-0000-0000-0000-00000000000d'), 0::bigint,
  'and their tracks');
select ok((select banned_until > now() + interval '3999 years' from auth.users
           where id = '00000000-0000-0000-0000-00000000000d'),
  'the account is banned for 4000 years');
select is((select count(*) from public.broadcast), 0::bigint, 'its broadcast too');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');

-- The dashboard SQL editor: a direct session, without a role claim
reset role;
select set_config('request.jwt.claims', '', true);
select is(auth.role(), null, 'a direct session has no role claim');
select lives_ok($$ select public.quarantine_user_by_channel_slug('user-radio') $$,
  'the SQL editor can moderate');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000a');

-- The log
select bag_eq(
  $$ select action, admin_id, channel_slugs from public.moderation_log $$,
  $$ values
     ('quarantine', '00000000-0000-0000-0000-00000000000a'::uuid, array['spam-radio', 'spam-radio-2']),
     ('quarantine', '00000000-0000-0000-0000-00000000000a'::uuid, array['spam-radio', 'spam-radio-2']),
     ('release', '00000000-0000-0000-0000-00000000000a'::uuid, array['spam-radio', 'spam-radio-2']),
     ('purge', null::uuid, array['spam-radio', 'spam-radio-2']),
     ('quarantine', null::uuid, array['user-radio']) $$,
  'admins read who did what');
select pg_temp.as_user('00000000-0000-0000-0000-00000000000c');
select is((select count(*) from public.moderation_log), 0::bigint, 'users do not read the log');

select * from finish();
rollback;
