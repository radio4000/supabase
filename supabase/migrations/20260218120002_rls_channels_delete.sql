-- Fix channels DELETE policy: was checking if user owns ANY channel,
-- not the specific channel being deleted.

DROP POLICY "Users can delete own channel." ON channels;

CREATE POLICY "Users can delete own channel." ON channels
  FOR DELETE
  USING (
    auth.uid() IN (
      SELECT user_id FROM user_channel WHERE user_channel.channel_id = channels.id
    )
  );
