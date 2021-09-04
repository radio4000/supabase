SET search_path TO public, auth;

/* -- Install extensions. pgcrypto allows us to use gen_random_uuid() */
-- CREATE EXTENSION pgcrypto;
CREATE EXTENSION IF NOT EXISTS moddatetime;

-- Drop exisiting tables
DROP TABLE if exists public.users;
DROP TABLE if exists channels CASCADE;
DROP TABLE if exists tracks CASCADE;
DROP TABLE if exists user_channel;
DROP TABLE if exists channel_track;

-- Create a table for public "users"
create table users (
	id uuid references auth.users not null,
	created_at timestamp with time zone default CURRENT_TIMESTAMP,
	updated_at timestamp with time zone default CURRENT_TIMESTAMP,
	primary key (id)
);

alter table users enable row level security;
create policy "Public users are viewable by everyone." on users for select using (true);
create policy "Users can insert their own user." on users for insert with check (auth.uid() = id);
create policy "Users can update own user." on users for update using (auth.uid() = id);

-- Create a table for public "channels"
create table channels (
	id uuid DEFAULT gen_random_uuid() primary key,
	name text not null,
	slug text unique not null,
	description text,
	url text,
	image text,
	created_at timestamp with time zone default CURRENT_TIMESTAMP,
	updated_at timestamp with time zone default CURRENT_TIMESTAMP,
	user_id uuid not null references auth.users(id) on delete cascade,
	unique(slug),
	constraint slug_length check (char_length(slug) >= 3)
);

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
	title text not null,
	description text
);

-- Create junction table for channel tracks
create table channel_track (
	user_id uuid not null references auth.users (id),
	channel_id uuid not null references channels (id) on delete cascade,
	track_id uuid not null references tracks (id) on delete cascade,
	created_at timestamp with time zone default CURRENT_TIMESTAMP,
	updated_at timestamp with time zone default CURRENT_TIMESTAMP,
	PRIMARY KEY (channel_id, track_id)
);

-- Track policies
alter table tracks enable row level security;
create policy "Public tracks are viewable by everyone." on tracks for select using (true);
create policy "Authenticated users can insert tracks" on tracks for insert with check (auth.role() = 'authenticated');
create policy "Users can update their own track." on tracks for update using (
	auth.uid() in (select user_id from channel_track where channel_track.user_id = auth.uid())
);
create policy "Users can delete own track." on tracks for delete using (
	auth.uid() in (select user_id from channel_track where channel_track.user_id = auth.uid())
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
alter publication supabase_realtime add table users;
alter publication supabase_realtime add table channels;

-- Create a procedure to delete the authenticated user
CREATE or replace function delete_user()
  returns void
LANGUAGE SQL SECURITY DEFINER
AS $$
	 delete from channels where user_id = auth.uid();
   delete from auth.users where id = auth.uid();
$$;

-- Automatically update "updated_at" timestamps
-- the trigger will set the "updated_at" column to the current timestamp for every update
create extension if not exists moddatetime schema extensions;
create trigger user_update before update on users
  for each row execute procedure moddatetime (updated_at);
create trigger channel_update before update on channels
  for each row execute procedure moddatetime (updated_at);
create trigger user_channel_update before update on user_channel
  for each row execute procedure moddatetime (updated_at);
create trigger channel_track_update before update on channel_track
  for each row execute procedure moddatetime (updated_at);
