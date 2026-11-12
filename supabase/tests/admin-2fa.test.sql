-- Admins act only with a fresh code from their authenticator app.
-- Run with: bunx supabase test db
begin;
create extension if not exists pgtap with schema extensions;
select plan(9);

insert into auth.users (id, email, raw_app_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'admin@example.org', '{"admin": true}'),
  ('00000000-0000-0000-0000-00000000000d', 'spam@example.org', '{}');
insert into public.channels (id, name, slug) values
  ('10000000-0000-0000-0000-00000000000d', 'Spam', 'spam-radio');
insert into public.user_channel (user_id, channel_id) values
  ('00000000-0000-0000-0000-00000000000d', '10000000-0000-0000-0000-00000000000d');

-- Signs in as the admin. aal and amr as Supabase signs them: a password
-- sign in is aal1; a verified code adds aal2 and its time to amr.
create function pg_temp.as_admin(aal text, amr jsonb) returns void language sql as $$
  select set_config('request.jwt.claims', jsonb_build_object(
           'sub', '00000000-0000-0000-0000-00000000000a', 'role', 'authenticated',
           'app_metadata', '{"admin": true}'::jsonb, 'aal', aal, 'amr', amr)::text, true),
         set_config('role', 'authenticated', true);
$$;
create function pg_temp.method(name text, at timestamptz) returns jsonb language sql as $$
  select jsonb_build_object('method', name, 'timestamp', extract(epoch from at)::bigint);
$$;

-- Signed in with a password only: reads, but can't act.
select pg_temp.as_admin('aal1', jsonb_build_array(pg_temp.method('password', now())));
select is(public.is_admin(), true, 'still an admin');
select lives_ok($$ select * from public.quarantined_accounts() $$, 'reads the queue without a code');
select throws_ok($$ select public.quarantine_user_by_channel_slug('spam-radio') $$,
  'admin code needed', 'cannot quarantine without a code');
select throws_ok($$ select public.release_user_by_channel_slug('spam-radio') $$,
  'admin code needed', 'cannot release without a code');

-- A code older than the period.
select pg_temp.as_admin('aal2', jsonb_build_array(pg_temp.method('password', now() - interval '1 day'),
                                                  pg_temp.method('totp', now() - interval '16 minutes')));
select throws_ok($$ select public.quarantine_user_by_channel_slug('spam-radio') $$,
  'admin code needed', 'cannot quarantine with an old code');

-- aal2 without a totp time (another factor, or a crafted claim) is refused.
select pg_temp.as_admin('aal2', jsonb_build_array(pg_temp.method('password', now())));
select throws_ok($$ select public.quarantine_user_by_channel_slug('spam-radio') $$,
  'admin code needed', 'aal2 alone is not enough');

-- A fresh code, after a sign in a day ago.
select pg_temp.as_admin('aal2', jsonb_build_array(pg_temp.method('password', now() - interval '1 day'),
                                                  pg_temp.method('totp', now() - interval '5 minutes')));
select lives_ok($$ select public.quarantine_user_by_channel_slug('spam-radio') $$,
  'quarantines with a fresh code');
select lives_ok($$ select public.release_user_by_channel_slug('spam-radio') $$,
  'releases with a fresh code');

-- The dashboard SQL editor has no token, and stays trusted.
reset role;
select set_config('request.jwt.claims', '', true);
select lives_ok($$ select public.quarantine_user_by_channel_slug('spam-radio') $$,
  'the SQL editor needs no code');

select * from finish();
rollback;
