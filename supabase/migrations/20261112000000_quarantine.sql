-- Moderation: admins quarantine spam accounts, which are deleted after a while.
--
-- Admins are accounts with "admin": true in their app_metadata, which only
-- the service role can set and which Supabase copies into the access token:
--
--   update auth.users
--   set raw_app_meta_data = raw_app_meta_data || '{"admin": true}'
--   where id = '...';
--
-- The flag reaches a session at its next token refresh (up to an hour).
--
-- Quarantine is a decision about an account, so it lives on accounts
-- (quarantined_at, quarantined_by). Quarantining an account, by the slug of
-- one of its channels:
-- - hides all its channels, their tracks and follows from everyone but
--   admins, and deletes its live broadcast;
-- - bans it for the quarantine period, so it can't sign in, write, or make a
--   new channel (the "Deny banned users" policies). Quarantine and ban share
--   auth.users.banned_until: releasing clears it.
-- Releasing undoes both: nothing was deleted.
-- Once the period is over, a daily job bans the account for good, which
-- deletes its channels and tracks. Every action goes to moderation_log.

create or replace function "public"."quarantine_period"() returns interval
  language sql
  immutable
  as $$ select interval '30 days' $$;

-- Admins

-- app_metadata, never user_metadata: users can write their own user_metadata
-- (auth.updateUser), so an admin flag there would make anyone an admin.
create or replace function "public"."is_admin"() returns boolean
  language sql
  stable
  set "search_path" to ''
  as $$
	select coalesce(auth.jwt() -> 'app_metadata' ->> 'admin', '') = 'true';
$$;

-- Used by the policies, so every role needs it.
grant execute on function "public"."is_admin"() to anon, authenticated, service_role;

create or replace function "public"."user_is_admin"("target_user_id" uuid) returns boolean
  language sql
  stable
  security definer
  set "search_path" to ''
  as $$
	select exists (
		select 1 from auth.users
		where id = target_user_id
			and coalesce(raw_app_meta_data ->> 'admin', '') = 'true'
	);
$$;

create or replace function "public"."require_admin"() returns void
  language plpgsql
  stable
  set "search_path" to ''
  as $$
begin
	if auth.role() is distinct from 'service_role' and not public.is_admin() then
		raise exception 'not authorized';
	end if;
end;
$$;

-- Quarantine

alter table "public"."accounts"
  add column "quarantined_at" timestamptz,
  add column "quarantined_by" uuid references auth.users (id) on delete set null;

create index "idx_accounts_quarantined_at" on "public"."accounts" ("quarantined_at")
  where "quarantined_at" is not null;

-- Users update their own account (theme…). Only the moderation functions
-- below (security definer, so not run as anon or authenticated) may set the
-- quarantine: a user who could would get their own account deleted.
create or replace function "public"."protect_quarantine"() returns trigger
  language plpgsql
  set "search_path" to ''
  as $$
begin
	if current_user in ('anon', 'authenticated')
		and (NEW.quarantined_at is distinct from (case when TG_OP = 'UPDATE' then OLD.quarantined_at end)
			or NEW.quarantined_by is distinct from (case when TG_OP = 'UPDATE' then OLD.quarantined_by end)) then
		raise exception 'only admins quarantine accounts';
	end if;
	return NEW;
end;
$$;

create trigger "accounts_protect_quarantine"
  before insert or update on "public"."accounts"
  for each row execute function "public"."protect_quarantine"();

-- The policies need these as every role, but the API must not serve them, or
-- anyone could list the quarantined accounts: they live in a schema that
-- PostgREST does not expose (config.toml: api.schemas).
create schema if not exists "private";
grant usage on schema "private" to anon, authenticated, service_role;

create or replace function "private"."quarantined_channel_ids"() returns setof uuid
  language sql
  stable
  security definer
  set "search_path" to ''
  as $$
	select uc.channel_id
	from public.accounts a
	join public.user_channel uc on uc.user_id = a.id
	where a.quarantined_at is not null;
$$;

create or replace function "private"."quarantined_track_ids"() returns setof uuid
  language sql
  stable
  security definer
  set "search_path" to ''
  as $$
	select ct.track_id
	from public.accounts a
	join public.user_channel uc on uc.user_id = a.id
	join public.channel_track ct on ct.channel_id = uc.channel_id
	where a.quarantined_at is not null;
$$;

revoke all on function "private"."quarantined_channel_ids"() from public;
revoke all on function "private"."quarantined_track_ids"() from public;
grant execute on function "private"."quarantined_channel_ids"() to anon, authenticated, service_role;
grant execute on function "private"."quarantined_track_ids"() to anon, authenticated, service_role;

-- What quarantined accounts own is hidden, except to admins. The views
-- (channel_tracks, channels_with_tracks, random_channels_with_tracks) are
-- security invoker, so these apply to them too. The not in (select ...) runs
-- once per query, as a hashed set: a function call per row would make a full
-- scan of tracks hundreds of times slower.

create policy "Hide quarantined accounts" on "public"."channels"
as restrictive for select to anon, authenticated
using ((select public.is_admin())
	or id not in (select private.quarantined_channel_ids()));

create policy "Hide quarantined accounts" on "public"."channel_track"
as restrictive for select to anon, authenticated
using ((select public.is_admin())
	or channel_id not in (select private.quarantined_channel_ids()));

create policy "Hide quarantined accounts" on "public"."tracks"
as restrictive for select to anon, authenticated
using ((select public.is_admin())
	or id not in (select private.quarantined_track_ids()));

create policy "Hide quarantined accounts" on "public"."followers"
as restrictive for select to anon, authenticated
using ((select public.is_admin())
	or (channel_id not in (select private.quarantined_channel_ids())
		and follower_id not in (select private.quarantined_channel_ids())));

-- Moderation log

create table "public"."moderation_log" (
  "id" uuid primary key default gen_random_uuid(),
  "created_at" timestamptz not null default now(),
  -- null for the service role and the daily job, or once the admin is deleted.
  "admin_id" uuid references auth.users (id) on delete set null,
  "action" text not null check ("action" in ('quarantine', 'release', 'ban', 'purge')),
  -- No foreign keys: the log outlives the user and the channels.
  "user_id" uuid not null,
  "channel_slugs" text[] not null default '{}'
);

alter table "public"."moderation_log" enable row level security;

create policy "Admins can read the moderation log" on "public"."moderation_log"
for select to authenticated
using ((select public.is_admin()));

-- Moderation functions

create or replace function "public"."channel_slug_owner"("channel_slug" text) returns uuid
  language plpgsql
  stable
  security definer
  set "search_path" to ''
  as $$
declare
	owners uuid[];
begin
	select array_agg(distinct uc.user_id)
	into owners
	from public.channels c
	join public.user_channel uc on uc.channel_id = c.id
	where c.slug = channel_slug;

	if owners is null then
		raise exception 'no owner found for channel slug %', channel_slug;
	end if;
	if cardinality(owners) > 1 then
		raise exception 'multiple owners found for channel slug %', channel_slug;
	end if;
	return owners[1];
end;
$$;

create or replace function "public"."user_channel_slugs"("target_user_id" uuid) returns text[]
  language sql
  stable
  security definer
  set "search_path" to ''
  as $$
	select coalesce(array_agg(c.slug order by c.slug), '{}')
	from public.channels c
	join public.user_channel uc on uc.channel_id = c.id
	where uc.user_id = target_user_id;
$$;

create or replace function "public"."log_moderation"("log_action" text, "target_user_id" uuid) returns void
  language sql
  security definer
  set "search_path" to ''
  as $$
	-- A purge is the daily job's, not the act of whoever runs it.
	insert into public.moderation_log (admin_id, action, user_id, channel_slugs)
	values (case when log_action = 'purge' then null else auth.uid() end,
		log_action, target_user_id, public.user_channel_slugs(target_user_id));
$$;

-- Bans TARGET_USER_ID until BAN_UNTIL and deletes their channels and tracks,
-- without checking who asks: only called by the functions below.
create or replace function "public"."delete_user_content"("target_user_id" uuid, "ban_until" timestamptz, "log_action" text) returns void
  language plpgsql
  security definer
  set "search_path" to ''
  as $$
begin
	perform public.log_moderation(log_action, target_user_id);

	-- This disables new logins; RLS blocks existing sessions immediately.
	update auth.users
	set banned_until = ban_until
	where id = target_user_id;

	-- The ban replaces the quarantine; the purge would otherwise come back.
	update public.accounts
	set quarantined_at = null, quarantined_by = null
	where id = target_user_id;

	delete from public.tracks
	where id in (
		select ct.track_id
		from public.channel_track ct
		join public.user_channel uc on uc.channel_id = ct.channel_id
		where uc.user_id = target_user_id
	);

	-- broadcast.channel_id has no on delete: remove it first, or a live
	-- account could not be deleted.
	delete from public.broadcast
	where channel_id in (select channel_id from public.user_channel where user_id = target_user_id);

	delete from public.channels
	where id in (select channel_id from public.user_channel where user_id = target_user_id);

	delete from public.user_channel where user_id = target_user_id;
end;
$$;

create or replace function "public"."ban_user"("target_user_id" uuid, "ban_until" timestamptz default (now() + '4000 years'::interval)) returns void
  language plpgsql
  security definer
  set "search_path" to ''
  as $$
begin
	perform public.require_admin();
	if public.user_is_admin(target_user_id) then
		raise exception 'cannot moderate an admin';
	end if;
	perform public.delete_user_content(target_user_id, ban_until, 'ban');
end;
$$;

create or replace function "public"."ban_user_by_channel_slug"("channel_slug" text, "ban_until" timestamptz default (now() + '4000 years'::interval)) returns void
  language plpgsql
  security definer
  set "search_path" to ''
  as $$
begin
	perform public.require_admin();
	perform public.ban_user(public.channel_slug_owner(channel_slug), ban_until);
end;
$$;

create or replace function "public"."quarantine_user_by_channel_slug"("channel_slug" text) returns void
  language plpgsql
  security definer
  set "search_path" to ''
  as $$
declare
	target_user_id uuid;
begin
	perform public.require_admin();
	target_user_id := public.channel_slug_owner(channel_slug);
	if public.user_is_admin(target_user_id) then
		raise exception 'cannot moderate an admin';
	end if;

	-- Accounts made before the accounts table may have no row.
	insert into public.accounts (id, quarantined_at, quarantined_by)
	values (target_user_id, now(), auth.uid())
	on conflict (id) do update
	set quarantined_at = excluded.quarantined_at, quarantined_by = excluded.quarantined_by
	where accounts.quarantined_at is null;
	if not found then
		raise exception 'the account of % is already quarantined', channel_slug;
	end if;

	update auth.users
	set banned_until = greatest(coalesce(banned_until, now()), now() + public.quarantine_period())
	where id = target_user_id;

	delete from public.broadcast
	where channel_id in (select channel_id from public.user_channel where user_id = target_user_id);

	perform public.log_moderation('quarantine', target_user_id);
end;
$$;

create or replace function "public"."release_user_by_channel_slug"("channel_slug" text) returns void
  language plpgsql
  security definer
  set "search_path" to ''
  as $$
declare
	target_user_id uuid;
begin
	perform public.require_admin();
	target_user_id := public.channel_slug_owner(channel_slug);

	update public.accounts
	set quarantined_at = null, quarantined_by = null
	where id = target_user_id and quarantined_at is not null;
	if not found then
		raise exception 'the account of % is not quarantined', channel_slug;
	end if;

	update auth.users set banned_until = null where id = target_user_id;

	perform public.log_moderation('release', target_user_id);
end;
$$;

-- The queue of the admins: quarantined accounts, their channels, and when
-- they will be purged.
create or replace function "public"."quarantined_accounts"()
  returns table ("user_id" uuid, "channel_slugs" text[], "quarantined_at" timestamptz,
                 "quarantined_by" uuid, "purge_at" timestamptz)
  language plpgsql
  stable
  security definer
  set "search_path" to ''
  as $$
begin
	perform public.require_admin();
	return query
		select a.id, public.user_channel_slugs(a.id), a.quarantined_at, a.quarantined_by,
			a.quarantined_at + public.quarantine_period()
		from public.accounts a
		where a.quarantined_at is not null
		order by a.quarantined_at;
end;
$$;

-- Run daily: ban for good the accounts quarantined for longer than the period.
-- An account that fails is skipped with a warning (in the cron logs), so it
-- can't hold back the others; it is tried again the next day.
create or replace function "public"."purge_quarantined"() returns integer
  language plpgsql
  security definer
  set "search_path" to ''
  as $$
declare
	target_user_id uuid;
	purged integer := 0;
begin
	for target_user_id in
		select id from public.accounts
		where quarantined_at < now() - public.quarantine_period()
	loop
		begin
			perform public.delete_user_content(target_user_id, now() + interval '4000 years', 'purge');
			purged := purged + 1;
		exception when others then
			raise warning 'purge_quarantined: account % failed: %', target_user_id, sqlerrm;
		end;
	end loop;
	return purged;
end;
$$;

-- Clients may call the moderation functions, which refuse anyone but admins;
-- the helpers are internal.
revoke all on function "public"."user_is_admin"(uuid) from public, anon, authenticated;
revoke all on function "public"."require_admin"() from public, anon;
revoke all on function "public"."channel_slug_owner"(text) from public, anon, authenticated;
revoke all on function "public"."user_channel_slugs"(uuid) from public, anon, authenticated;
revoke all on function "public"."log_moderation"(text, uuid) from public, anon, authenticated;
revoke all on function "public"."delete_user_content"(uuid, timestamptz, text) from public, anon, authenticated;
revoke all on function "public"."purge_quarantined"() from public, anon, authenticated;

revoke all on function "public"."ban_user"(uuid, timestamptz) from public, anon;
revoke all on function "public"."ban_user_by_channel_slug"(text, timestamptz) from public, anon;
revoke all on function "public"."quarantine_user_by_channel_slug"(text) from public, anon;
revoke all on function "public"."release_user_by_channel_slug"(text) from public, anon;
revoke all on function "public"."quarantined_accounts"() from public, anon;
grant execute on function "public"."require_admin"() to authenticated, service_role;
grant execute on function "public"."ban_user"(uuid, timestamptz) to authenticated, service_role;
grant execute on function "public"."ban_user_by_channel_slug"(text, timestamptz) to authenticated, service_role;
grant execute on function "public"."quarantine_user_by_channel_slug"(text) to authenticated, service_role;
grant execute on function "public"."release_user_by_channel_slug"(text) to authenticated, service_role;
grant execute on function "public"."quarantined_accounts"() to authenticated, service_role;

create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule('purge-quarantined', '17 3 * * *', $$select public.purge_quarantined()$$);
