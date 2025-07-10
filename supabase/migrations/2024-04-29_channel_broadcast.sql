-- Broadcast cleanup
DROP TABLE if exists broadcast;

-- broadcast junction table (channel + track)
create table broadcast (
	channel_id uuid not null references channels (id),
	track_id uuid not null references tracks (id),
	track_played_at timestamp with time zone not null,
	created_at timestamp with time zone default CURRENT_TIMESTAMP,
	updated_at timestamp with time zone default CURRENT_TIMESTAMP,
	PRIMARY KEY (channel_id)
);

-- Broadcast table subscriptions
alter publication supabase_realtime add table broadcast;

-- Broadcast trigger for `updated_at`
create trigger broadcast_update before update on broadcast
	for each row execute procedure moddatetime(updated_at);

-- Broadcast policies
alter table broadcast enable row level security;
create policy "Broadcasts are viewable by everyone" on broadcast for select using (true);
create policy "User can insert own channel broadcast." on user_channel for insert with check (
 auth.uid() in (select user_id from user_channel where channel_id = channel_id)
);
create policy "User can update own channel broadcast." on broadcast for update using (
	auth.uid() in (select user_id from user_channel where channel_id = channel_id)
);
create policy "Users can delete channel junction." on broadcast for delete using (
	auth.uid() in (select user_id from user_channel where channel_id = channel_id)
);
