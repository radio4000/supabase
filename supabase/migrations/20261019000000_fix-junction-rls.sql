-- Close RLS holes in the junction tables.
--
-- user_channel: INSERT only checked user_id, so any signed-in user could add
-- themselves as owner of any channel. The policy can't tell a creator from a
-- stranger, because the owner row is the only link between a user and a
-- channel. So the database now writes the owner row itself when a channel is
-- created, and clients can no longer insert into user_channel.
--
-- channel_track: INSERT only checked user_id, so anyone could link tracks
-- into someone else's channel. Now the caller must own the channel.
--
-- Both UPDATE policies had no WITH CHECK, so an owned row could be repointed
-- at another channel or track. Nothing updates junction rows; drop them.
--
-- Deploy only after clients stop inserting the owner row themselves
-- (@radio4000/sdk skips it when the row already exists).

create or replace function "public"."add_channel_owner"() returns "trigger"
  language "plpgsql"
  security definer
  set "search_path" to ''
  as $$
begin
  if auth.uid() is not null then
    insert into public.user_channel (user_id, channel_id)
    values (auth.uid(), NEW.id);
  end if;
  return NEW;
end;
$$;

create trigger "channels_add_owner"
  after insert on "public"."channels"
  for each row execute function "public"."add_channel_owner"();

drop policy "User can insert channel junction." on "public"."user_channel";
drop policy "Users can update channel junction." on "public"."user_channel";

drop policy "User can insert their junction." on "public"."channel_track";
create policy "User can insert their junction." on "public"."channel_track" for INSERT
with
  check (
    (select auth.uid()) = user_id
    and exists (
      select 1 from public.user_channel uc
      where uc.channel_id = channel_track.channel_id
        and uc.user_id = (select auth.uid())
    )
  );

drop policy "Users can update own junction." on "public"."channel_track";
