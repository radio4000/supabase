-- Add PostGIS extension for geography data types (the map)
create extension if not exists postgis schema extensions;

-- Drop exisiting tables
DROP TABLE if exists public.accounts;
DROP TABLE if exists channels CASCADE;
DROP TABLE if exists channel_track CASCADE;
DROP TABLE if exists tracks CASCADE;
DROP TABLE if exists user_channel;

-- Make sure all users are deleted
DELETE FROM auth.users;

-- Create a table for public user accounts
create table accounts (
	id uuid references auth.users not null,
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
	-- Computed column with name, slug and description for full-text search
	fts tsvector generated always as (to_tsvector('english', name || ' ' || slug || ' ' || description)) stored;
	created_at timestamp with time zone default CURRENT_TIMESTAMP,
	updated_at timestamp with time zone default CURRENT_TIMESTAMP,
	-- user_id uuid not null references auth.users(id) on delete cascade,
	unique(slug),
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
	mentions text[]
	fts tsvector generated always as (to_tsvector('english', title || ' ' || description)) stored;
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

-- Create junction table for a channel following channel
create table channel_follow (
	follower_channel_id uuid not null references channels (id) on delete cascade,
	following_channel_id uuid not null references channels (id) on delete cascade,
	created_at timestamp with time zone default CURRENT_TIMESTAMP,
	PRIMARY KEY (follower_channel_id, following_channel_id)
);

-- channel_follow policies
alter table channel_follow enable row level security;

create policy "Channel follow relationships are viewable by everyone" on channel_follow for select using (true);

create policy "User can insert channel follow relationship." on channel_follow for insert
with check (
	auth.uid() in (select user_id from user_channel where channel_id = follower_channel_id)
);

create policy "Users can delete channel follow relationship." on channel_follow for delete
using (
	auth.uid() in (select user_id from user_channel where channel_id = follower_channel_id)
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
alter publication supabase_realtime add table channel_follow;

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
