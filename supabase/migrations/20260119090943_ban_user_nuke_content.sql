-- Shadow banning and hard-delete moderation

create or replace function public.is_banned()
	returns boolean
	language sql
	stable
as $$
	-- Access tokens are stateless; this makes bans effective immediately via RLS.
	select exists (
		select 1
		from auth.users
		where id = auth.uid()
			and banned_until > now()
	);
$$;

create policy "Deny banned users" on public.accounts
	as restrictive for all
	to authenticated
	using (not public.is_banned())
	with check (not public.is_banned());

create policy "Deny banned users" on public.channels
	as restrictive for all
	to authenticated
	using (not public.is_banned())
	with check (not public.is_banned());

create policy "Deny banned users" on public.tracks
	as restrictive for all
	to authenticated
	using (not public.is_banned())
	with check (not public.is_banned());

create policy "Deny banned users" on public.user_channel
	as restrictive for all
	to authenticated
	using (not public.is_banned())
	with check (not public.is_banned());

create policy "Deny banned users" on public.channel_track
	as restrictive for all
	to authenticated
	using (not public.is_banned())
	with check (not public.is_banned());

create policy "Deny banned users" on public.followers
	as restrictive for all
	to authenticated
	using (not public.is_banned())
	with check (not public.is_banned());

create or replace function public.ban_user(
	target_user_id uuid,
	ban_reason text default null,
	ban_until timestamp with time zone default now() + interval '4000 years'
)
	returns void
	language plpgsql
	security definer
	set search_path = public
as $$
begin
	if auth.role() <> 'service_role' then
		raise exception 'not authorized';
	end if;

	-- This disables new logins; RLS blocks existing sessions immediately.
	update auth.users
	set banned_until = ban_until
	where id = target_user_id;

	with target_channels as (
		select uc.channel_id
		from public.user_channel uc
		where uc.user_id = target_user_id
	),
	tracks_to_delete as (
		select distinct ct.track_id
		from public.channel_track ct
		where ct.channel_id in (select channel_id from target_channels)
	)
	delete from public.tracks
	where id in (select track_id from tracks_to_delete);

	with target_channels as (
		select uc.channel_id
		from public.user_channel uc
		where uc.user_id = target_user_id
	)
	delete from public.channels
	where id in (select channel_id from target_channels);

	delete from public.user_channel where user_id = target_user_id;
end;
$$;

create or replace function public.ban_user_by_channel_slug(
	channel_slug text,
	ban_reason text default null,
	ban_until timestamp with time zone default now() + interval '4000 years'
)
	returns void
	language plpgsql
	security definer
	set search_path = public
as $$
declare
	target_user_id uuid;
	user_count int;
begin
	if auth.role() <> 'service_role' then
		raise exception 'not authorized';
	end if;

	select count(distinct uc.user_id)
	into user_count
	from public.channels c
	join public.user_channel uc on uc.channel_id = c.id
	where c.slug = channel_slug;

	if user_count is null or user_count = 0 then
		raise exception 'no owner found for channel slug %', channel_slug;
	end if;

	if user_count > 1 then
		raise exception 'multiple owners found for channel slug %', channel_slug;
	end if;

	select uc.user_id
	into target_user_id
	from public.channels c
	join public.user_channel uc on uc.channel_id = c.id
	where c.slug = channel_slug
	limit 1;

	perform public.ban_user(target_user_id, ban_reason, ban_until);
end;
$$;

revoke execute on function public.ban_user(uuid, text, timestamp with time zone)
	from anon, public, authenticated;

revoke execute on function public.ban_user_by_channel_slug(text, text, timestamp with time zone)
	from anon, public, authenticated;
