create table if not exists "public"."accounts" (
  "id" "uuid" not null,
  "theme" "text",
  "color_scheme" "text",
  "created_at" timestamp with time zone default CURRENT_TIMESTAMP not null,
  "updated_at" timestamp with time zone default CURRENT_TIMESTAMP not null
);

create table if not exists "public"."broadcast" (
  "channel_id" "uuid" not null,
  "track_id" "uuid",
  "track_played_at" timestamp with time zone not null,
  "created_at" timestamp with time zone default CURRENT_TIMESTAMP not null,
  "updated_at" timestamp with time zone default CURRENT_TIMESTAMP not null,
  "decks" "jsonb"
);

create table if not exists "public"."channel_track" (
  "user_id" "uuid" not null,
  "channel_id" "uuid" not null,
  "track_id" "uuid" not null,
  "created_at" timestamp with time zone default CURRENT_TIMESTAMP not null,
  "updated_at" timestamp with time zone default CURRENT_TIMESTAMP not null
);

create table if not exists "public"."channels" (
  "id" "uuid" default "gen_random_uuid" () not null,
  "name" "text" not null,
  "slug" "text" not null,
  "description" "text",
  "url" "text",
  "image" "text",
  "longitude" double precision,
  "latitude" double precision,
  "coordinates" "extensions"."geography" (Point, 4326),
  "favorites" "text" [],
  "followers" "text" [],
  "firebase_id" "text",
  "fts" "tsvector" GENERATED ALWAYS as (
    (
      (
        (
          (
            "setweight" (
              "to_tsvector" (
                '"english"'::"regconfig",
                COALESCE("name", ''::"text")
              ),
              'A'::"char"
            ) || ''::"tsvector"
          ) || "setweight" (
            "to_tsvector" (
              '"english"'::"regconfig",
              COALESCE("slug", ''::"text")
            ),
            'B'::"char"
          )
        ) || ''::"tsvector"
      ) || "setweight" (
        "to_tsvector" (
          '"english"'::"regconfig",
          COALESCE("description", ''::"text")
        ),
        'C'::"char"
      )
    )
  ) STORED,
  "created_at" timestamp with time zone default CURRENT_TIMESTAMP not null,
  "updated_at" timestamp with time zone default CURRENT_TIMESTAMP not null,
  constraint "slug_length" check (("char_length" ("slug") >= 3))
);

create table if not exists "public"."tracks" (
  "id" "uuid" default "gen_random_uuid" () not null,
  "created_at" timestamp with time zone default CURRENT_TIMESTAMP not null,
  "updated_at" timestamp with time zone default CURRENT_TIMESTAMP not null,
  "url" "text" not null,
  "discogs_url" "text",
  "title" "text" not null,
  "description" "text",
  "tags" "text" [],
  "mentions" "text" [],
  "fts" "tsvector" GENERATED ALWAYS as (
    (
      (
        "setweight" (
          "to_tsvector" (
            '"english"'::"regconfig",
            COALESCE("title", ''::"text")
          ),
          'A'::"char"
        ) || ''::"tsvector"
      ) || "setweight" (
        "to_tsvector" (
          '"english"'::"regconfig",
          COALESCE("description", ''::"text")
        ),
        'B'::"char"
      )
    )
  ) STORED,
  "duration" integer,
  "playback_error" "text",
  "provider" "text",
  "media_id" "text"
);

COMMENT on column "public"."tracks"."duration" is 'Duration of the track in seconds (nullable if unavailable, for exemple when track media is broken)';

COMMENT on column "public"."tracks"."playback_error" is 'Non-null when last playback attempt failed; may contain provider error message or code';

COMMENT on column "public"."tracks"."provider" is 'Media provider derived from URL (e.g., youtube, soundcloud, vimeo)';

COMMENT on column "public"."tracks"."media_id" is 'Provider-specific media identifier extracted from URL';

create table if not exists "public"."followers" (
  "follower_id" "uuid" not null,
  "channel_id" "uuid" not null,
  "created_at" timestamp with time zone default CURRENT_TIMESTAMP not null
);

create table if not exists "public"."user_channel" (
  "user_id" "uuid" not null,
  "channel_id" "uuid" not null,
  "created_at" timestamp with time zone default CURRENT_TIMESTAMP not null,
  "updated_at" timestamp with time zone default CURRENT_TIMESTAMP not null
);

create table if not exists "public"."reserved_slugs" (
  "slug" "text" not null,
  "created_at" timestamp with time zone default "now" ()
);

alter table only "public"."accounts"
add constraint "accounts_pkey" primary key ("id");

alter table only "public"."broadcast"
add constraint "broadcast_pkey" primary key ("channel_id");

alter table only "public"."channel_track"
add constraint "channel_track_pkey" primary key ("channel_id", "track_id");

alter table only "public"."channel_track"
add constraint "channel_track_track_id_unique" unique ("track_id");

alter table only "public"."channels"
add constraint "channels_firebase_id_key" unique ("firebase_id");

alter table only "public"."channels"
add constraint "channels_pkey" primary key ("id");

alter table only "public"."channels"
add constraint "channels_slug_key" unique ("slug");

alter table only "public"."followers"
add constraint "followers_pkey" primary key ("follower_id", "channel_id");

alter table only "public"."reserved_slugs"
add constraint "reserved_slugs_pkey" primary key ("slug");

alter table only "public"."tracks"
add constraint "tracks_pkey" primary key ("id");

alter table only "public"."user_channel"
add constraint "user_channel_pkey" primary key ("user_id", "channel_id");

create index "channels_fts" on "public"."channels" using "gin" ("fts");

create index "channels_slug_index" on "public"."channels" using "btree" ("slug");

create index "tracks_fts" on "public"."tracks" using "gin" ("fts");

-- Indexes for RLS policy subquery performance.
-- Many policies look up user_id by channel_id in these junction tables.
create index "idx_user_channel_channel_id" on "public"."user_channel" ("channel_id");
create index "idx_channel_track_channel_id" on "public"."channel_track" ("channel_id");

create
or REPLACE TRIGGER "broadcast_update" BEFORE
update on "public"."broadcast" for EACH row
execute FUNCTION "extensions"."moddatetime" ('updated_at');

create
or REPLACE TRIGGER "channel_track_update" BEFORE
update on "public"."channel_track" for EACH row
execute FUNCTION "extensions"."moddatetime" ('updated_at');

create
or REPLACE TRIGGER "channel_update" BEFORE
update on "public"."channels" for EACH row
execute FUNCTION "extensions"."moddatetime" ('updated_at');

create
or REPLACE TRIGGER "parse_track_url_trigger" BEFORE INSERT
or
update OF "url" on "public"."tracks" for EACH row
execute FUNCTION "public"."parse_track_url" ();

create
or REPLACE TRIGGER "prevent_reserved_channel_slug" BEFORE INSERT
or
update OF "slug" on "public"."channels" for EACH row
execute FUNCTION "public"."check_reserved_slug" ();

create
or REPLACE TRIGGER "track_update" BEFORE
update on "public"."tracks" for EACH row
execute FUNCTION "extensions"."moddatetime" ('updated_at');

create
or REPLACE TRIGGER "update_tags" BEFORE INSERT
or
update on "public"."tracks" for EACH row
execute FUNCTION "public"."parse_track_description" ();

create
or REPLACE TRIGGER "user_channel_update" BEFORE
update on "public"."user_channel" for EACH row
execute FUNCTION "extensions"."moddatetime" ('updated_at');

create
or REPLACE TRIGGER "user_update" BEFORE
update on "public"."accounts" for EACH row
execute FUNCTION "extensions"."moddatetime" ('updated_at');

alter table only "public"."accounts"
add constraint "accounts_id_fkey" foreign KEY ("id") references "auth"."users" ("id") on delete CASCADE;

alter table only "public"."broadcast"
add constraint "broadcast_channel_id_fkey" foreign KEY ("channel_id") references "public"."channels" ("id");

alter table only "public"."channel_track"
add constraint "channel_track_channel_id_fkey" foreign KEY ("channel_id") references "public"."channels" ("id") on delete CASCADE;

alter table only "public"."channel_track"
add constraint "channel_track_track_id_fkey" foreign KEY ("track_id") references "public"."tracks" ("id") on delete CASCADE;

alter table only "public"."channel_track"
add constraint "channel_track_user_id_fkey" foreign KEY ("user_id") references "auth"."users" ("id") on delete CASCADE;

alter table only "public"."followers"
add constraint "followers_channel_id_fkey" foreign KEY ("channel_id") references "public"."channels" ("id") on delete CASCADE;

alter table only "public"."followers"
add constraint "followers_follower_id_fkey" foreign KEY ("follower_id") references "public"."channels" ("id") on delete CASCADE;

alter table only "public"."user_channel"
add constraint "user_channel_channel_id_fkey" foreign KEY ("channel_id") references "public"."channels" ("id") on delete CASCADE;

alter table only "public"."user_channel"
add constraint "user_channel_user_id_fkey" foreign KEY ("user_id") references "auth"."users" ("id") on delete CASCADE;

create policy "Authenticated users can create a channel" on "public"."channels" for INSERT
with
  check (("auth"."role" () = 'authenticated'::"text"));

create policy "Authenticated users can insert tracks" on "public"."tracks" for INSERT
with
  check (("auth"."role" () = 'authenticated'::"text"));

create policy "Broadcasts are viewable by everyone" on "public"."broadcast" for
select
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

alter table "public"."accounts" ENABLE row LEVEL SECURITY;

alter table "public"."broadcast" ENABLE row LEVEL SECURITY;

alter table "public"."channel_track" ENABLE row LEVEL SECURITY;

alter table "public"."channels" ENABLE row LEVEL SECURITY;

alter table "public"."followers" ENABLE row LEVEL SECURITY;

create policy "relationships are viewable by everyone" on "public"."followers" for
select
  using (true);

alter table "public"."reserved_slugs" ENABLE row LEVEL SECURITY;

alter table "public"."tracks" ENABLE row LEVEL SECURITY;

alter table "public"."user_channel" ENABLE row LEVEL SECURITY;

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
