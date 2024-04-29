-- Channel Broadcast cleanup
DROP TABLE if exists channel_broadcast;

-- channel_broadcast junction table (channel + track)
create table channel_broadcast (
	channel_id uuid not null references channels (id),
	track_id uuid not null references tracks (id),
	created_at timestamp with time zone default CURRENT_TIMESTAMP,
	updated_at timestamp with time zone default CURRENT_TIMESTAMP,
	PRIMARY KEY (channel_id)
);

-- Channel broadcast table subscriptions
alter publication supabase_realtime add table channel_broadcast;

-- Channel broadcast trigger for `updated_at`
create trigger channel_broadcast_update before update on channel_broadcast
	for each row execute procedure moddatetime(updated_at);

-- Channel Broadcast policies
alter table channel_broadcast enable row level security;
create policy "Channel Broadcast are viewable by everyone" on channel_broadcast for select using (true);
create policy "User can insert own channel broadcast." on user_channel for insert with check (
 auth.uid() in (select user_id from user_channel where channel_id = channel_id)
);
create policy "User can update own channel broadcast." on channel_broadcast for update using (
	auth.uid() in (select user_id from user_channel where channel_id = channel_id)
);
create policy "Users can delete channel junction." on channel_broadcast for delete using (
	auth.uid() in (select user_id from user_channel where channel_id = channel_id)
);
