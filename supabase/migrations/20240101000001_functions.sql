CREATE OR REPLACE FUNCTION "public"."parse_tokens"("content" "text", "prefix" "text") RETURNS "text"[]
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog', 'public'
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


CREATE OR REPLACE FUNCTION "public"."parse_track_description"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    SET "search_path" TO 'pg_catalog', 'public'
    AS $$
	BEGIN
		new.tags = parse_tokens(new.description, '#');
		new.mentions = parse_tokens(new.description, '@');
		RETURN new;
	END;
$$;


CREATE OR REPLACE FUNCTION "public"."parse_track_url"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
DECLARE
	url_text text;
	host text;
	path text;
	query_v text;
	extracted_id text;
	segments text[];
	username text;
	track_slug text;
BEGIN
	url_text := NEW.url;

	-- Default to NULL
	NEW.provider := NULL;
	NEW.media_id := NULL;

	IF url_text IS NULL OR url_text = '' THEN
		RETURN NEW;
	END IF;

	-- Handle missing protocol (e.g., "youtube.com/watch?v=xxx")
	IF url_text NOT LIKE '%://%' THEN
		url_text := 'https://' || url_text;
	END IF;

	-- Extract host (remove www. prefix)
	host := (regexp_matches(url_text, '://(?:www\.)?([^/]+)', 'i'))[1];
	IF host IS NULL THEN
		RETURN NEW;
	END IF;

	-- Extract path
	path := (regexp_matches(url_text, '://[^/]+(/[^?#]*)', 'i'))[1];
	IF path IS NULL THEN path := '/'; END IF;

	-- Extract ?v= query parameter for YouTube
	query_v := (regexp_matches(url_text, '[?&]v=([a-zA-Z0-9_-]{11})', 'i'))[1];

	--
	-- YouTube: youtube.com, m.youtube.com, music.youtube.com, youtu.be
	-- Patterns: watch?v=, /embed/, /shorts/, /live/, /v/, /e/, youtu.be/
	--
	IF host = 'youtu.be' THEN
		extracted_id := (regexp_matches(path, '^/([a-zA-Z0-9_-]{11})', 'i'))[1];
		IF extracted_id IS NOT NULL THEN
			NEW.provider := 'youtube';
			NEW.media_id := extracted_id;
			RETURN NEW;
		END IF;
	END IF;

	IF host = 'youtube.com' OR host LIKE '%.youtube.com' THEN
		-- watch?v={id}
		IF query_v IS NOT NULL THEN
			NEW.provider := 'youtube';
			NEW.media_id := query_v;
			RETURN NEW;
		END IF;

		-- /embed/{id}, /shorts/{id}, /live/{id}, /v/{id}, /e/{id}
		extracted_id := (regexp_matches(path, '^/(embed|shorts|live|v|e)/([a-zA-Z0-9_-]{11})', 'i'))[2];
		IF extracted_id IS NOT NULL THEN
			NEW.provider := 'youtube';
			NEW.media_id := extracted_id;
			RETURN NEW;
		END IF;
	END IF;

	--
	-- Vimeo: vimeo.com, player.vimeo.com
	-- Patterns: /{id}, /video/{id}
	--
	IF host = 'vimeo.com' OR host = 'player.vimeo.com' THEN
		-- /video/{id} (player embed)
		extracted_id := (regexp_matches(path, '^/video/(\d+)', 'i'))[1];
		IF extracted_id IS NOT NULL THEN
			NEW.provider := 'vimeo';
			NEW.media_id := extracted_id;
			RETURN NEW;
		END IF;

		-- /{id} (direct)
		extracted_id := (regexp_matches(path, '^/(\d+)', 'i'))[1];
		IF extracted_id IS NOT NULL THEN
			NEW.provider := 'vimeo';
			NEW.media_id := extracted_id;
			RETURN NEW;
		END IF;
	END IF;

	--
	-- Spotify: open.spotify.com/track/{id}
	-- Only tracks, not playlists/albums. Handles optional /intl-{locale}/ prefix
	--
	IF host = 'open.spotify.com' THEN
		extracted_id := (regexp_matches(path, '^(?:/intl-[a-z]+)?/track/([a-zA-Z0-9]+)', 'i'))[1];
		IF extracted_id IS NOT NULL THEN
			NEW.provider := 'spotify';
			NEW.media_id := extracted_id;
			RETURN NEW;
		END IF;
	END IF;

	--
	-- Discogs: discogs.com/release/{id} or /master/{id}
	-- ID may be followed by slug: /release/12345-Artist-Album
	--
	IF host = 'discogs.com' THEN
		extracted_id := (regexp_matches(path, '/(release|master)/(\d+)', 'i'))[2];
		IF extracted_id IS NOT NULL THEN
			NEW.provider := 'discogs';
			NEW.media_id := extracted_id;
			RETURN NEW;
		END IF;
	END IF;

	--
	-- SoundCloud: soundcloud.com/{path}
	-- Also handles m.soundcloud.com (mobile)
	-- Accepts tracks, sets, playlists - any path with 2+ segments
	--
	IF host = 'soundcloud.com' OR host = 'm.soundcloud.com' THEN
		-- Extract path segments
		segments := regexp_split_to_array(trim(both '/' from path), '/');

		-- Need at least 2 segments (username + something)
		IF array_length(segments, 1) >= 2 THEN
			username := segments[1];

			-- Reject reserved paths (not user content)
			IF username NOT IN ('discover', 'stream', 'upload', 'you', 'search',
				'charts', 'messages', 'settings', 'notifications', 'people',
				'terms-of-use', 'pages') THEN
				NEW.provider := 'soundcloud';
				NEW.media_id := trim(both '/' from path);
				RETURN NEW;
			END IF;
		END IF;
	END IF;

	RETURN NEW;
END;
$$;


CREATE OR REPLACE FUNCTION "public"."check_reserved_slug"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM reserved_slugs WHERE slug = NEW.slug) THEN
    RAISE EXCEPTION 'Slug "%" is reserved', NEW.slug;
  END IF;
  RETURN NEW;
END;
$$;
