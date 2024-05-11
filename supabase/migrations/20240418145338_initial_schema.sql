-- Add PostGIS extension for geography data types (the map)
set pgaudit.log = 'none';
create extension if not exists postgis schema extensions;
set pgaudit.log = 'ddl';

-- Drop exisiting tables
DROP TABLE if exists public.accounts;
DROP TABLE if exists channels CASCADE;
DROP TABLE if exists channel_track CASCADE;
DROP TABLE if exists tracks CASCADE;
DROP TABLE if exists user_channel;
DROP TABLE if exists followers;

-- Make sure all users are deleted
DELETE FROM auth.users;

-- Create a table for public user accounts
create table accounts (
	id uuid not null references auth.users (id) on delete cascade,
	theme text,
	color_scheme text,
	created_at timestamp with time zone default CURRENT_TIMESTAMP,
	updated_at timestamp with time zone default CURRENT_TIMESTAMP,
	primary key (id)
);

alter table accounts enable row level security;
create policy "Users can only read their own accounts." on accounts for select using (auth.uid() = id);
create policy "Users can only insert their own account." on accounts for insert with check (auth.uid() = id);
create policy "Users can only update own account." on accounts for update using (auth.uid() = id);

-- Create a table for public "channels"
create table channels (
	id uuid DEFAULT gen_random_uuid() primary key,
	name text not null,
	slug text unique not null,
	description text,
	url text,
	image text,
	longitude float,
	latitude float,
	coordinates geography(POINT),

	favorites text[],
	followers text[],
	firebase_id text null,

	-- Computed column with for full-text search
	fts tsvector generated always as (
		setweight(to_tsvector('english', coalesce(name, '')), 'A') || ' ' ||
		setweight(to_tsvector('english', coalesce(slug, '')), 'B') || ' ' ||
		setweight(to_tsvector('english', coalesce(description, '')), 'C')
	) stored,

	created_at timestamp with time zone default CURRENT_TIMESTAMP,
	updated_at timestamp with time zone default CURRENT_TIMESTAMP,
	-- user_id uuid not null references auth.users(id) on delete cascade,
	unique(slug),
	unique(firebase_id),
	constraint slug_length check (char_length(slug) >= 3)
);

-- Faster when we query by slug and search
create index channels_slug_index on channels (slug);
create index channels_fts on channels using gin (fts);

-- Create junction table for user >< channel
create table user_channel (
	user_id uuid not null references auth.users (id) on delete cascade,
	channel_id uuid not null references channels (id) on delete cascade,
	created_at timestamp with time zone default CURRENT_TIMESTAMP,
	updated_at timestamp with time zone default CURRENT_TIMESTAMP,
	PRIMARY KEY (user_id, channel_id)
);

-- Channel policies
alter table channels enable row level security;
create policy "Channels are viewable by everyone." on channels for select using (true);
create policy "Authenticated users can create a channel" on channels for insert with check (auth.role() = 'authenticated');
create policy "Users can update own channel." on channels for update
using (
	auth.uid() in (select user_id from public.user_channel where channel_id = id and user_id = auth.uid())
)
with check (
	auth.uid() in (select user_id from public.user_channel where channel_id = id and user_id = auth.uid())
);
create policy "Users can delete own channel." on channels for delete using (
	auth.uid() in (select user_id from user_channel where user_channel.user_id = auth.uid())
);

-- User Channel policies
alter table user_channel enable row level security;
create policy "User channel junctions are viewable by everyone" on user_channel for select using (true);
create policy "User can insert channel junction." on user_channel for insert with check (auth.uid() = user_id);
create policy "Users can update channel junction." on user_channel for update using (auth.uid() = user_id);
create policy "Users can delete channel junction." on user_channel for delete using (auth.uid() = user_id);

-- Create tracks table
create table tracks (
	id uuid DEFAULT gen_random_uuid() primary key,
	created_at timestamp with time zone default CURRENT_TIMESTAMP,
	updated_at timestamp with time zone default CURRENT_TIMESTAMP,
	url text not null,
	discogs_url text,
	title text not null,
	description text,
	tags text[],
	mentions text[],
	-- Computed column with for full-text search
	fts tsvector generated always as (
		setweight(to_tsvector('english', coalesce(title, '')), 'A') || ' ' ||
		setweight(to_tsvector('english', coalesce(description, '')), 'B')
	) stored
);

create index tracks_fts on tracks using gin (fts);

-- Create junction table for channel tracks
create table channel_track (
	user_id uuid not null references auth.users (id) on delete cascade,
	channel_id uuid not null references channels (id) on delete cascade,
	track_id uuid not null references tracks (id) on delete cascade,
	created_at timestamp with time zone default CURRENT_TIMESTAMP,
	updated_at timestamp with time zone default CURRENT_TIMESTAMP,
	PRIMARY KEY (channel_id, track_id)
);

-- A view for tracks which adds the channel.slug column
create view channel_tracks as
	select
		tracks.id,
		tracks.created_at,
		tracks.updated_at,
		tracks.url,
		tracks.discogs_url,
		tracks.title,
		tracks.description,
		tracks.tags,
		tracks.mentions,
		tracks.fts,
		channels.slug
	from tracks
	join channel_track on tracks.id = channel_track.track_id
	join channels on channels.id = channel_track.channel_id;

-- Create junction table for a channel following channel
create table followers (
	follower_id uuid not null references channels (id) on delete cascade,
	channel_id uuid not null references channels (id) on delete cascade,
	created_at timestamp with time zone default CURRENT_TIMESTAMP,
	PRIMARY KEY (follower_id, channel_id)
);

-- Followers policies
alter table followers enable row level security;

create policy "relationships are viewable by everyone" on followers for select using (true);

create policy "User can insert channel follow relationship." on followers for insert
with check (
	auth.uid() in (select user_id from user_channel where channel_id = follower_id)
);

create policy "Users can delete channel follow relationship." on followers for delete
using (
	auth.uid() in (select user_id from user_channel where channel_id = follower_id)
);

-- Track policies
alter table tracks enable row level security;
create policy "Public tracks are viewable by everyone." on tracks for select using (true);
create policy "Authenticated users can insert tracks" on tracks for insert with check (auth.role() = 'authenticated');
create policy "Users can update their own track." on tracks for update using (
	auth.uid() in (select user_id from channel_track where track_id = id)
);
create policy "Users can delete own track." on tracks for delete using (
	auth.uid() in (select user_id from channel_track where track_id = id)
);

-- Channel track policies
alter table channel_track enable row level security;
create policy "User track junctions are viewable by everyone" on channel_track for select using (true);
create policy "User can insert their junction." on channel_track for insert with check (auth.uid() = user_id);
create policy "Users can update own junction." on channel_track for update using (auth.uid() = user_id);
create policy "Users can delete own junction." on channel_track for delete using (auth.uid() = user_id);


-- Set up Realtime!
begin;
	drop publication if exists supabase_realtime;
	create publication supabase_realtime;
commit;
alter publication supabase_realtime add table channels;
alter publication supabase_realtime add table tracks;
alter publication supabase_realtime add table user_channel;
alter publication supabase_realtime add table followers;
alter publication supabase_realtime add table accounts;

-- Create a procedure to delete the authenticated user
CREATE or replace function delete_user()
	returns void
LANGUAGE SQL SECURITY DEFINER
AS $$
	-- delete from channels where user_id = auth.uid();
	delete from user_channel where user_id = auth.uid();
	delete from auth.users where id = auth.uid();
$$;

-- Automatically update "updated_at" timestamps
-- the trigger will set the "updated_at" column to the current timestamp for every update
create extension if not exists moddatetime schema extensions;
create trigger user_update before update on accounts
	for each row execute procedure moddatetime(updated_at);
create trigger channel_update before update on channels
	for each row execute procedure moddatetime(updated_at);
create trigger user_channel_update before update on user_channel
	for each row execute procedure moddatetime(updated_at);
create trigger channel_track_update before update on channel_track
	for each row execute procedure moddatetime(updated_at);
create trigger track_update before update on tracks
	for each row execute procedure moddatetime(updated_at);

-- Usage: parse_tokens(myString, '#')
CREATE or replace FUNCTION parse_tokens(content text, prefix text)
	RETURNS text[]
	LANGUAGE plpgsql
AS $$
	DECLARE
		regex text;
		matches text;
		subquery text;
		captures text;
		tokens text[];
	BEGIN
		regex := prefix || '(\S+)';
		matches := 'regexp_matches($1, $2, $3) as captures';
		subquery := '(SELECT ' || matches || ' ORDER BY captures) as matches';
		captures := 'array_agg(matches.captures[1])';

		EXECUTE 'SELECT ' || captures || ' FROM ' || subquery
		INTO tokens
		USING LOWER(content), regex, 'g';

		IF tokens IS NULL THEN
			tokens = '{}';
		END IF;

		RETURN tokens;
	END;
$$;

create or replace function parse_track_description()
	returns trigger
	language plpgsql
as $$
	begin
		new.tags = parse_tokens(new.description, '#');
		new.mentions = parse_tokens(new.description, '@');
		return new;
	end;
$$;

create trigger update_tags
	before insert or update on tracks
	for each row execute procedure parse_track_description();
