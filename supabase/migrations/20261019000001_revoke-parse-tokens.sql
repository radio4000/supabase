-- parse_tokens builds a regex from its prefix argument, so exposing it as
-- /rpc/parse_tokens lets anyone send expensive patterns. It's only used by
-- the parse_track_description trigger.
--
-- That trigger runs as the inserting user, so make it security definer
-- first, or revoking would break every track insert.
alter function "public"."parse_track_description"() security definer;

revoke execute on function "public"."parse_tokens"("content" "text", "prefix" "text") from public, anon, authenticated;
