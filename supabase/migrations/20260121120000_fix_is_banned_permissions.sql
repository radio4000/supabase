-- Fix: is_banned() needs security definer to read auth.users
create or replace function public.is_banned()
	returns boolean
	language sql
	stable
	security definer
	set search_path = public
as $$
	select exists (
		select 1
		from auth.users
		where id = auth.uid()
			and banned_until > now()
	);
$$;
