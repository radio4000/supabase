-- Wrap auth.uid() and auth.role() calls in (select ...) subqueries
-- so PostgreSQL evaluates them once per query instead of per row.
-- See: https://supabase.com/docs/guides/database/postgres/row-level-security#call-functions-with-select

-- channels
drop policy "Authenticated users can create a channel" on "public"."channels";
create policy "Authenticated users can create a channel" on "public"."channels" for INSERT
with
  check (((select auth.role()) = 'authenticated'::text));

drop policy "Users can delete own channel." on "public"."channels";
create policy "Users can delete own channel." on "public"."channels" for DELETE using (
  (
    (select auth.uid()) in (
      select
        user_channel.user_id
      from
        public.user_channel
      where
        (user_channel.channel_id = channels.id)
    )
  )
);

drop policy "Users can update own channel." on "public"."channels";
create policy "Users can update own channel." on "public"."channels"
for update
  using (
    (
      (select auth.uid()) in (
        select
          user_channel.user_id
        from
          public.user_channel
        where
          (
            (user_channel.channel_id = channels.id)
            and (user_channel.user_id = (select auth.uid()))
          )
      )
    )
  )
with
  check (
    (
      (select auth.uid()) in (
        select
          user_channel.user_id
        from
          public.user_channel
        where
          (
            (user_channel.channel_id = channels.id)
            and (user_channel.user_id = (select auth.uid()))
          )
      )
    )
  );

-- tracks
drop policy "Authenticated users can insert tracks" on "public"."tracks";
create policy "Authenticated users can insert tracks" on "public"."tracks" for INSERT
with
  check (((select auth.role()) = 'authenticated'::text));

drop policy "Users can delete own track." on "public"."tracks";
create policy "Users can delete own track." on "public"."tracks" for DELETE using (
  (
    (select auth.uid()) in (
      select
        channel_track.user_id
      from
        public.channel_track
      where
        (channel_track.track_id = tracks.id)
    )
  )
);

drop policy "Users can update their own track." on "public"."tracks";
create policy "Users can update their own track." on "public"."tracks"
for update
  using (
    (
      (select auth.uid()) in (
        select
          channel_track.user_id
        from
          public.channel_track
        where
          (channel_track.track_id = tracks.id)
      )
    )
  );

-- broadcast
drop policy "User can delete own channel broadcast." on "public"."broadcast";
create policy "User can delete own channel broadcast." on "public"."broadcast" for DELETE using (
  (
    (select auth.uid()) in (
      select
        user_channel.user_id
      from
        public.user_channel
      where
        (user_channel.channel_id = broadcast.channel_id)
    )
  )
);

drop policy "User can insert own channel broadcast." on "public"."broadcast";
create policy "User can insert own channel broadcast." on "public"."broadcast" for INSERT
with
  check (
    (
      (select auth.uid()) in (
        select
          user_channel.user_id
        from
          public.user_channel
        where
          (user_channel.channel_id = broadcast.channel_id)
        )
    )
  );

drop policy "User can update own channel broadcast." on "public"."broadcast";
create policy "User can update own channel broadcast." on "public"."broadcast"
for update
  using (
    (
      (select auth.uid()) in (
        select
          user_channel.user_id
        from
          public.user_channel
        where
          (user_channel.channel_id = broadcast.channel_id)
        )
    )
  );

-- accounts
drop policy "Users can only insert their own account." on "public"."accounts";
create policy "Users can only insert their own account." on "public"."accounts" for INSERT
with
  check (((select auth.uid()) = id));

drop policy "Users can only read their own accounts." on "public"."accounts";
create policy "Users can only read their own accounts." on "public"."accounts" for
select
  using (((select auth.uid()) = id));

drop policy "Users can only update own account." on "public"."accounts";
create policy "Users can only update own account." on "public"."accounts"
for update
  using (((select auth.uid()) = id));

-- user_channel
drop policy "User can insert channel junction." on "public"."user_channel";
create policy "User can insert channel junction." on "public"."user_channel" for INSERT
with
  check (((select auth.uid()) = user_id));

drop policy "Users can delete channel junction." on "public"."user_channel";
create policy "Users can delete channel junction." on "public"."user_channel" for DELETE using (((select auth.uid()) = user_id));

drop policy "Users can update channel junction." on "public"."user_channel";
create policy "Users can update channel junction." on "public"."user_channel"
for update
  using (((select auth.uid()) = user_id));

-- channel_track
drop policy "User can insert their junction." on "public"."channel_track";
create policy "User can insert their junction." on "public"."channel_track" for INSERT
with
  check (((select auth.uid()) = user_id));

drop policy "Users can delete own junction." on "public"."channel_track";
create policy "Users can delete own junction." on "public"."channel_track" for DELETE using (((select auth.uid()) = user_id));

drop policy "Users can update own junction." on "public"."channel_track";
create policy "Users can update own junction." on "public"."channel_track"
for update
  using (((select auth.uid()) = user_id));

-- followers
drop policy "User can insert channel follow relationship." on "public"."followers";
create policy "User can insert channel follow relationship." on "public"."followers" for INSERT
with
  check (
    (
      (select auth.uid()) in (
        select
          user_channel.user_id
        from
          public.user_channel
        where
          (user_channel.channel_id = followers.follower_id)
      )
    )
  );

drop policy "Users can delete channel follow relationship." on "public"."followers";
create policy "Users can delete channel follow relationship." on "public"."followers" for DELETE using (
  (
    (select auth.uid()) in (
      select
        user_channel.user_id
      from
        public.user_channel
      where
        (user_channel.channel_id = followers.follower_id)
    )
  )
);
