-- Admins act with a fresh code from their authenticator app (2FA, TOTP),
-- not with their everyday sign in: a radio left signed in on a shared
-- computer can't quarantine anyone. Reading the queue needs no code.
-- See docs/moderation.md.

-- How long a code lets an admin act.
create or replace function "public"."admin_code_period"() returns interval
  language sql
  immutable
  set "search_path" to ''
  as $$ select interval '15 minutes' $$;

-- True if the session verified a code within the period. Supabase signs
-- these claims: aal2 after a second factor, and amr the time of each
-- method, which a token refresh keeps.
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

drop function "public"."require_admin"();

create or replace function "public"."require_admin"("fresh_code" boolean default true) returns void
  language plpgsql
  stable
  set "search_path" to ''
  as $$
begin
	-- No role claim: a direct database session (dashboard SQL editor, psql,
	-- pg_cron), open only to those with database access. Requests through
	-- the API always carry one, anon included.
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
		select a.id, public.user_channel_slugs(a.id), a.quarantined_at, a.quarantined_by,
			a.quarantined_at + public.quarantine_period()
		from public.accounts a
		where a.quarantined_at is not null
		order by a.quarantined_at;
end;
$$;

revoke all on function "public"."require_admin"(boolean) from public, anon;
grant execute on function "public"."require_admin"(boolean) to authenticated, service_role;
grant execute on function "public"."has_fresh_code"() to anon, authenticated, service_role;
grant execute on function "public"."admin_code_period"() to anon, authenticated, service_role;
