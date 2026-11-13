-- Admins quarantine spam accounts: their channels are hidden, the account is
-- banned, and a daily job purges it after 30 days. See docs/moderation.md.
-- Replaces ban_user and ban_user_by_channel_slug.

create or replace function "public"."quarantine_period"() returns interval
  language sql
  immutable
  as $$ select interval '30 days' $$;

-- Admins

-- app_metadata, never user_metadata, which users can write themselves.
create or replace function "public"."is_admin"() returns boolean
  language sql
  stable
  set "search_path" to ''
  as $$
	select coalesce(auth.jwt() -> 'app_metadata' ->> 'admin', '') = 'true';
$$;

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

-- How long a 2FA code lets an admin act.
create or replace function "public"."admin_code_period"() returns interval
  language sql
  immutable
  set "search_path" to ''
  as $$ select interval '15 minutes' $$;

-- True if the session verified a TOTP code within the period.
create or replace function "public"."has_fresh_code"() returns boolean
  language sql
  stable
  set "search_path" to ''
  as $$
	select coalesce(auth.jwt() ->> 'aal' = 'aal2', false)
		and exists (
			select 1 from jsonb_array_elements(coalesce(auth.jwt() -> 'amr', '[]'::jsonb)) as m
			where m ->> 'method' = 'totp'
				and to_timestamp((m ->> 'timestamp')::double precision)
					> now() - public.admin_code_period());
$$;

grant execute on function "public"."has_fresh_code"() to anon, authenticated, service_role;
grant execute on function "public"."admin_code_period"() to anon, authenticated, service_role;

-- Refuses non-admins, and admins without a fresh code if fresh_code.
create or replace function "public"."require_admin"("fresh_code" boolean default true) returns void
  language plpgsql
  stable
  set "search_path" to ''
  as $$
begin
	-- No role claim: a direct session (SQL editor, pg_cron).
	if auth.role() is null or auth.role() = 'service_role' then
		return;
	end if;
	if not public.is_admin() then
		raise exception 'not authorized';
	end if;
	if fresh_code and not public.has_fresh_code() then
		raise exception 'admin code needed'
			using hint = 'Verify a code from your authenticator app, then try again.';
	end if;
end;
$$;

-- Quarantine

alter table "public"."channels"
  add column "quarantined_at" timestamptz,
  add column "quarantined_by" uuid references auth.users (id) on delete set null;

create index "idx_channels_quarantined_at" on "public"."channels" ("quarantined_at")
  where "quarantined_at" is not null;

-- Users can't set or clear the quarantine on their own channels.
create or replace function "public"."protect_quarantine"() returns trigger
  language plpgsql
  set "search_path" to ''
  as $$
begin
	if current_user in ('anon', 'authenticated')
		and (NEW.quarantined_at is distinct from (case when TG_OP = 'UPDATE' then OLD.quarantined_at end)
			or NEW.quarantined_by is distinct from (case when TG_OP = 'UPDATE' then OLD.quarantined_by end)) then
		raise exception 'only admins quarantine channels';
	end if;
	return NEW;
end;
$$;

create trigger "channels_protect_quarantine"
  before insert or update on "public"."channels"
  for each row execute function "public"."protect_quarantine"();

-- A check on the row itself, so normal reads don't slow down with spam.
-- Tracks need no policy: the views join channels.
create policy "Hide quarantined channels" on "public"."channels"
as restrictive for select to anon, authenticated
using ("quarantined_at" is null or (select public.is_admin()));

-- Moderation log

create table "public"."moderation_log" (
  "id" uuid primary key default gen_random_uuid(),
  "created_at" timestamptz not null default now(),
  -- null for the SQL editor and the daily job.
  "admin_id" uuid references auth.users (id) on delete set null,
  "action" text not null check ("action" in ('quarantine', 'release', 'purge')),
  -- No foreign key: the log outlives the user.
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
	insert into public.moderation_log (admin_id, action, user_id, channel_slugs)
	values (case when log_action = 'purge' then null else auth.uid() end,
		log_action, target_user_id, public.user_channel_slugs(target_user_id));
$$;

drop function "public"."ban_user_by_channel_slug"(text, timestamptz);
drop function "public"."ban_user"(uuid, timestamptz);

-- No auth check: only purge_quarantined calls it.
create or replace function "public"."purge_account"("target_user_id" uuid) returns void
  language plpgsql
  security definer
  set "search_path" to ''
  as $$
begin
	perform public.log_moderation('purge', target_user_id);

	-- Keep the user row so the email can't sign up again.
	update auth.users
	set banned_until = now() + interval '4000 years'
	where id = target_user_id;

	delete from public.tracks
	where id in (
		select ct.track_id
		from public.channel_track ct
		join public.user_channel uc on uc.channel_id = ct.channel_id
		where uc.user_id = target_user_id
	);

	-- broadcast.channel_id has no on delete cascade.
	delete from public.broadcast
	where channel_id in (select channel_id from public.user_channel where user_id = target_user_id);

	delete from public.channels
	where id in (select channel_id from public.user_channel where user_id = target_user_id);

	delete from public.user_channel where user_id = target_user_id;
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

	if exists (
		select 1 from public.channels c
		join public.user_channel uc on uc.channel_id = c.id
		where uc.user_id = target_user_id and c.quarantined_at is not null
	) then
		raise exception 'the account of % is already quarantined', channel_slug;
	end if;

	update public.channels
	set quarantined_at = now(), quarantined_by = auth.uid()
	where id in (select channel_id from public.user_channel where user_id = target_user_id);

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

	update public.channels
	set quarantined_at = null, quarantined_by = null
	where id in (select channel_id from public.user_channel where user_id = target_user_id)
		and quarantined_at is not null;
	if not found then
		raise exception 'the account of % is not quarantined', channel_slug;
	end if;

	update auth.users set banned_until = null where id = target_user_id;

	perform public.log_moderation('release', target_user_id);
end;
$$;

create or replace function "public"."quarantined_accounts"()
  returns table ("user_id" uuid, "channel_slugs" text[], "quarantined_at" timestamptz,
                 "quarantined_by" uuid, "purge_at" timestamptz)
  language plpgsql
  stable
  security definer
  set "search_path" to ''
  as $$
begin
	perform public.require_admin(fresh_code => false);
	return query
		select uc.user_id, array_agg(c.slug order by c.slug), min(c.quarantined_at),
			min(c.quarantined_by::text)::uuid, min(c.quarantined_at) + public.quarantine_period()
		from public.channels c
		join public.user_channel uc on uc.channel_id = c.id
		where c.quarantined_at is not null
		group by uc.user_id
		order by 3;
end;
$$;

-- Daily. A failing account is logged and retried tomorrow.
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
		select distinct uc.user_id
		from public.channels c
		join public.user_channel uc on uc.channel_id = c.id
		where c.quarantined_at < now() - public.quarantine_period()
	loop
		begin
			perform public.purge_account(target_user_id);
			purged := purged + 1;
		exception when others then
			raise warning 'purge_quarantined: account % failed: %', target_user_id, sqlerrm;
		end;
	end loop;
	return purged;
end;
$$;

revoke all on function "public"."user_is_admin"(uuid) from public, anon, authenticated;
revoke all on function "public"."require_admin"(boolean) from public, anon;
revoke all on function "public"."channel_slug_owner"(text) from public, anon, authenticated;
revoke all on function "public"."user_channel_slugs"(uuid) from public, anon, authenticated;
revoke all on function "public"."log_moderation"(text, uuid) from public, anon, authenticated;
revoke all on function "public"."purge_account"(uuid) from public, anon, authenticated;
revoke all on function "public"."purge_quarantined"() from public, anon, authenticated;

revoke all on function "public"."quarantine_user_by_channel_slug"(text) from public, anon;
revoke all on function "public"."release_user_by_channel_slug"(text) from public, anon;
revoke all on function "public"."quarantined_accounts"() from public, anon;
grant execute on function "public"."require_admin"(boolean) to authenticated, service_role;
grant execute on function "public"."quarantine_user_by_channel_slug"(text) to authenticated, service_role;
grant execute on function "public"."release_user_by_channel_slug"(text) to authenticated, service_role;
grant execute on function "public"."quarantined_accounts"() to authenticated, service_role;

create extension if not exists pg_cron with schema pg_catalog;

select cron.schedule('purge-quarantined', '17 3 * * *', $$select public.purge_quarantined()$$);
