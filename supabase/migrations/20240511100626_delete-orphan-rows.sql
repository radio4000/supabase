-- Overwrite the existing function with new functionality.
-- The two last lines ensure that any orphaned channels and tracks are also deleted.
CREATE or replace function delete_user()
	returns void
LANGUAGE SQL SECURITY DEFINER
AS $$
	-- Delete user's associations with channels
	delete from user_channel where user_id = auth.uid();

	-- Delete account and user
	delete from accounts where id = auth.uid();
	delete from auth.users where id = auth.uid();

	-- Delete any orphaned channels
	delete from channels where id not in (select channel_id from user_channel);

	-- Delete any orphaned tracks
	delete from tracks where id not in (select track_id from channel_track);
$$;

