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
create index "idx_channel_track_channel_created" on "public"."channel_track" ("channel_id", "created_at" desc);

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
