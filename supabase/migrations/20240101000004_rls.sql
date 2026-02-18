alter table "public"."accounts" ENABLE row LEVEL SECURITY;

alter table "public"."broadcast" ENABLE row LEVEL SECURITY;

alter table "public"."channel_track" ENABLE row LEVEL SECURITY;

alter table "public"."channels" ENABLE row LEVEL SECURITY;

alter table "public"."followers" ENABLE row LEVEL SECURITY;

alter table "public"."reserved_slugs" ENABLE row LEVEL SECURITY;

alter table "public"."tracks" ENABLE row LEVEL SECURITY;

alter table "public"."user_channel" ENABLE row LEVEL SECURITY;

create policy "Authenticated users can create a channel" on "public"."channels" for INSERT
with
  check (("auth"."role" () = 'authenticated'::"text"));

create policy "Authenticated users can insert tracks" on "public"."tracks" for INSERT
with
  check (("auth"."role" () = 'authenticated'::"text"));

create policy "Broadcasts are publicly readable" on "public"."broadcast" for
select to anon, authenticated
  using (true);

create policy "Channels are viewable by everyone." on "public"."channels" for
select
  using (true);

create policy "Deny banned users" on "public"."accounts" as RESTRICTIVE to "authenticated" using ((not "public"."is_banned" ()))
with
  check ((not "public"."is_banned" ()));

create policy "Deny banned users" on "public"."broadcast" as RESTRICTIVE to "authenticated" using ((not "public"."is_banned" ()))
with
  check ((not "public"."is_banned" ()));

create policy "Deny banned users" on "public"."channel_track" as RESTRICTIVE to "authenticated" using ((not "public"."is_banned" ()))
with
  check ((not "public"."is_banned" ()));

create policy "Deny banned users" on "public"."channels" as RESTRICTIVE to "authenticated" using ((not "public"."is_banned" ()))
with
  check ((not "public"."is_banned" ()));

create policy "Deny banned users" on "public"."followers" as RESTRICTIVE to "authenticated" using ((not "public"."is_banned" ()))
with
  check ((not "public"."is_banned" ()));

create policy "Deny banned users" on "public"."tracks" as RESTRICTIVE to "authenticated" using ((not "public"."is_banned" ()))
with
  check ((not "public"."is_banned" ()));

create policy "Deny banned users" on "public"."user_channel" as RESTRICTIVE to "authenticated" using ((not "public"."is_banned" ()))
with
  check ((not "public"."is_banned" ()));

create policy "Public tracks are viewable by everyone." on "public"."tracks" for
select
  using (true);

create policy "Reserved slugs are viewable by everyone" on "public"."reserved_slugs" for
select
  using (true);

create policy "User can delete own channel broadcast." on "public"."broadcast" for DELETE using (
  (
    "auth"."uid" () in (
      select
        "user_channel"."user_id"
      from
        "public"."user_channel"
      where
        (
          "user_channel"."channel_id" = "broadcast"."channel_id"
        )
    )
  )
);

create policy "User can insert channel follow relationship." on "public"."followers" for INSERT
with
  check (
    (
      "auth"."uid" () in (
        select
          "user_channel"."user_id"
        from
          "public"."user_channel"
        where
          (
            "user_channel"."channel_id" = "followers"."follower_id"
          )
      )
    )
  );

create policy "User can insert channel junction." on "public"."user_channel" for INSERT
with
  check (("auth"."uid" () = "user_id"));

create policy "User can insert own channel broadcast." on "public"."broadcast" for INSERT
with
  check (
    (
      "auth"."uid" () in (
        select
          "user_channel"."user_id"
        from
          "public"."user_channel"
        where
          (
            "user_channel"."channel_id" = "broadcast"."channel_id"
          )
      )
    )
  );

create policy "User can insert their junction." on "public"."channel_track" for INSERT
with
  check (("auth"."uid" () = "user_id"));

create policy "User can update own channel broadcast." on "public"."broadcast"
for update
  using (
    (
      "auth"."uid" () in (
        select
          "user_channel"."user_id"
        from
          "public"."user_channel"
        where
          (
            "user_channel"."channel_id" = "broadcast"."channel_id"
          )
      )
    )
  );

create policy "User channel junctions are viewable by everyone" on "public"."user_channel" for
select
  using (true);

create policy "User track junctions are viewable by everyone" on "public"."channel_track" for
select
  using (true);

create policy "Users can delete channel follow relationship." on "public"."followers" for DELETE using (
  (
    "auth"."uid" () in (
      select
        "user_channel"."user_id"
      from
        "public"."user_channel"
      where
        (
          "user_channel"."channel_id" = "followers"."follower_id"
        )
    )
  )
);

create policy "Users can delete channel junction." on "public"."user_channel" for DELETE using (("auth"."uid" () = "user_id"));

create policy "Users can delete own channel." on "public"."channels" for DELETE using (
  (
    "auth"."uid" () in (
      select
        "user_channel"."user_id"
      from
        "public"."user_channel"
      where
        ("user_channel"."channel_id" = "channels"."id")
    )
  )
);

create policy "Users can delete own junction." on "public"."channel_track" for DELETE using (("auth"."uid" () = "user_id"));

create policy "Users can delete own track." on "public"."tracks" for DELETE using (
  (
    "auth"."uid" () in (
      select
        "channel_track"."user_id"
      from
        "public"."channel_track"
      where
        ("channel_track"."track_id" = "tracks"."id")
    )
  )
);

create policy "Users can only insert their own account." on "public"."accounts" for INSERT
with
  check (("auth"."uid" () = "id"));

create policy "Users can only read their own accounts." on "public"."accounts" for
select
  using (("auth"."uid" () = "id"));

create policy "Users can only update own account." on "public"."accounts"
for update
  using (("auth"."uid" () = "id"));

create policy "Users can update channel junction." on "public"."user_channel"
for update
  using (("auth"."uid" () = "user_id"));

create policy "Users can update own channel." on "public"."channels"
for update
  using (
    (
      "auth"."uid" () in (
        select
          "user_channel"."user_id"
        from
          "public"."user_channel"
        where
          (
            ("user_channel"."channel_id" = "channels"."id")
            and ("user_channel"."user_id" = "auth"."uid" ())
          )
      )
    )
  )
with
  check (
    (
      "auth"."uid" () in (
        select
          "user_channel"."user_id"
        from
          "public"."user_channel"
        where
          (
            ("user_channel"."channel_id" = "channels"."id")
            and ("user_channel"."user_id" = "auth"."uid" ())
          )
      )
    )
  );

create policy "Users can update own junction." on "public"."channel_track"
for update
  using (("auth"."uid" () = "user_id"));

create policy "Users can update their own track." on "public"."tracks"
for update
  using (
    (
      "auth"."uid" () in (
        select
          "channel_track"."user_id"
        from
          "public"."channel_track"
        where
          ("channel_track"."track_id" = "tracks"."id")
      )
    )
  );

create policy "relationships are viewable by everyone" on "public"."followers" for
select
  using (true);

-- Realtime
alter publication "supabase_realtime"
add table only "public"."accounts";

alter publication "supabase_realtime"
add table only "public"."broadcast";

alter publication "supabase_realtime"
add table only "public"."channels";

alter publication "supabase_realtime"
add table only "public"."followers";

alter publication "supabase_realtime"
add table only "public"."tracks";

alter publication "supabase_realtime"
add table only "public"."user_channel";

-- Auto-create account row on signup
create
or REPLACE TRIGGER "on_auth_user_created"
after INSERT on "auth"."users" for EACH row
execute FUNCTION "public"."handle_new_user" ();
