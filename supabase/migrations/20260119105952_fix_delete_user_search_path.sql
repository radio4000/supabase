-- Harden delete_user() by pinning search_path.

create or replace function public.delete_user()
	returns void
	language sql
	security definer
	set search_path = public
as $$
	with target_channels as (
		select channel_id
		from public.user_channel
		where user_id = auth.uid()
	),
	tracks_to_delete as (
		select distinct ct.track_id
		from public.channel_track ct
		where ct.channel_id in (select channel_id from target_channels)
	)
	delete from public.tracks
	where id in (select track_id from tracks_to_delete);

	with target_channels as (
		select channel_id
		from public.user_channel
		where user_id = auth.uid()
	)
	delete from public.channels
	where id in (select channel_id from target_channels);

	delete from public.user_channel where user_id = auth.uid();
	delete from auth.users where id = auth.uid();
$$;
