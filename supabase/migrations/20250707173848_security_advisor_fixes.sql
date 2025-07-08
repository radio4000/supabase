-- Security Advisor Fixes
-- Fix for parse_tokens function: correct search_path and security invoker
CREATE OR REPLACE FUNCTION parse_tokens(content text, prefix text)
	RETURNS text[]
	LANGUAGE plpgsql
	SECURITY INVOKER
	SET search_path TO 'pg_catalog', 'public'
AS $$
DECLARE
	regex text;
	tokens text[];
BEGIN
	regex := prefix || '(\S+)';
	
	-- Direct query without dynamic SQL
	SELECT array_agg(captures[1])
	INTO tokens
	FROM (
		SELECT regexp_matches(LOWER(content), regex, 'g') AS captures
		ORDER BY captures
	) AS matches;

	IF tokens IS NULL THEN
		tokens = '{}';
	END IF;

	RETURN tokens;
END;
$$;

-- Fix for parse_track_description function: correct search_path and security invoker
CREATE OR REPLACE FUNCTION parse_track_description()
	RETURNS trigger
	LANGUAGE plpgsql
	SECURITY INVOKER
	SET search_path TO 'pg_catalog', 'public'
AS $$
	BEGIN
		new.tags = parse_tokens(new.description, '#');
		new.mentions = parse_tokens(new.description, '@');
		RETURN new;
	END;
$$;

-- Fix for mutable search path
CREATE or replace function delete_user()
	returns void
LANGUAGE SQL SECURITY DEFINER
SET search_path TO 'pg_catalog', 'public' -- Explicit search path for security
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
