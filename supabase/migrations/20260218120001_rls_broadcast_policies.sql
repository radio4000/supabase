-- Fix broadcast RLS policies:
-- 1. INSERT was accidentally created on user_channel instead of broadcast
-- 2. UPDATE and DELETE have a self-join bug (user_channel.channel_id = user_channel.channel_id)
--    which lets any channel owner update/delete any broadcast

-- Move the stray INSERT policy from user_channel to broadcast
DROP POLICY "User can insert own channel broadcast." ON user_channel;

CREATE POLICY "User can insert own channel broadcast." ON broadcast
  FOR INSERT
  WITH CHECK (
    auth.uid() IN (
      SELECT user_id FROM user_channel WHERE user_channel.channel_id = broadcast.channel_id
    )
  );

-- Fix UPDATE: reference broadcast.channel_id instead of self-join
DROP POLICY "User can update own channel broadcast." ON broadcast;

CREATE POLICY "User can update own channel broadcast." ON broadcast
  FOR UPDATE
  USING (
    auth.uid() IN (
      SELECT user_id FROM user_channel WHERE user_channel.channel_id = broadcast.channel_id
    )
  );

-- Fix DELETE: reference broadcast.channel_id instead of self-join
DROP POLICY "Users can delete channel junction." ON broadcast;

CREATE POLICY "User can delete own channel broadcast." ON broadcast
  FOR DELETE
  USING (
    auth.uid() IN (
      SELECT user_id FROM user_channel WHERE user_channel.channel_id = broadcast.channel_id
    )
  );
