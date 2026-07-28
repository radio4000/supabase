-- Evaluate the authenticated user's ban status once per statement instead of
-- once per row. This matters especially for security-invoker views such as
-- channel_tracks, which joins several RLS-protected tables.
--
-- Wrapping a row-independent security-definer function in SELECT lets
-- PostgreSQL cache it as an initPlan.

drop policy "Deny banned users" on public.accounts;
create policy "Deny banned users" on public.accounts
as restrictive to authenticated
using (not (select public.is_banned()))
with check (not (select public.is_banned()));

drop policy "Deny banned users" on public.broadcast;
create policy "Deny banned users" on public.broadcast
as restrictive to authenticated
using (not (select public.is_banned()))
with check (not (select public.is_banned()));

drop policy "Deny banned users" on public.channel_track;
create policy "Deny banned users" on public.channel_track
as restrictive to authenticated
using (not (select public.is_banned()))
with check (not (select public.is_banned()));

drop policy "Deny banned users" on public.channels;
create policy "Deny banned users" on public.channels
as restrictive to authenticated
using (not (select public.is_banned()))
with check (not (select public.is_banned()));

drop policy "Deny banned users" on public.followers;
create policy "Deny banned users" on public.followers
as restrictive to authenticated
using (not (select public.is_banned()))
with check (not (select public.is_banned()));

drop policy "Deny banned users" on public.tracks;
create policy "Deny banned users" on public.tracks
as restrictive to authenticated
using (not (select public.is_banned()))
with check (not (select public.is_banned()));

drop policy "Deny banned users" on public.user_channel;
create policy "Deny banned users" on public.user_channel
as restrictive to authenticated
using (not (select public.is_banned()))
with check (not (select public.is_banned()));
