-- Extend parse_track_url() to classify direct media files as provider='file'.
-- Keep unknown URLs as NULL provider/media_id.

CREATE OR REPLACE FUNCTION public.parse_track_url()
	RETURNS trigger
	LANGUAGE plpgsql
	SET search_path TO 'pg_catalog', 'public'
AS $function$
	DECLARE
		url_text text;
		host text;
		path text;
		query_v text;
		extracted_id text;
		segments text[];
		username text;
	BEGIN
		url_text := NEW.url;
		NEW.provider := NULL;
		NEW.media_id := NULL;

		IF url_text IS NULL OR url_text = '' THEN
			RETURN NEW;
		END IF;

		IF url_text NOT LIKE '%://%' THEN
			url_text := 'https://' || url_text;
		END IF;

		host := (regexp_matches(url_text, '://(?:www\.)?([^/]+)', 'i'))[1];
		IF host IS NULL THEN
			RETURN NEW;
		END IF;

		path := (regexp_matches(url_text, '://[^/]+(/[^?#]*)', 'i'))[1];
		IF path IS NULL THEN
			path := '/';
		END IF;

		query_v := (regexp_matches(url_text, '[?&]v=([a-zA-Z0-9_-]{11})', 'i'))[1];

		IF host = 'youtu.be' THEN
			extracted_id := (regexp_matches(path, '^/([a-zA-Z0-9_-]{11})', 'i'))[1];
			IF extracted_id IS NOT NULL THEN
				NEW.provider := 'youtube';
				NEW.media_id := extracted_id;
				RETURN NEW;
			END IF;
		END IF;

		IF host = 'youtube.com' OR host LIKE '%.youtube.com' THEN
			IF query_v IS NOT NULL THEN
				NEW.provider := 'youtube';
				NEW.media_id := query_v;
				RETURN NEW;
			END IF;

			extracted_id := (regexp_matches(path, '^/(embed|shorts|live|v|e)/([a-zA-Z0-9_-]{11})', 'i'))[2];
			IF extracted_id IS NOT NULL THEN
				NEW.provider := 'youtube';
				NEW.media_id := extracted_id;
				RETURN NEW;
			END IF;
		END IF;

		IF host = 'vimeo.com' OR host = 'player.vimeo.com' THEN
			extracted_id := (regexp_matches(path, '^/video/(\d+)', 'i'))[1];
			IF extracted_id IS NOT NULL THEN
				NEW.provider := 'vimeo';
				NEW.media_id := extracted_id;
				RETURN NEW;
			END IF;

			extracted_id := (regexp_matches(path, '^/(\d+)', 'i'))[1];
			IF extracted_id IS NOT NULL THEN
				NEW.provider := 'vimeo';
				NEW.media_id := extracted_id;
				RETURN NEW;
			END IF;
		END IF;

		IF host = 'open.spotify.com' THEN
			extracted_id := (regexp_matches(path, '^(?:/intl-[a-z]+)?/track/([a-zA-Z0-9]+)', 'i'))[1];
			IF extracted_id IS NOT NULL THEN
				NEW.provider := 'spotify';
				NEW.media_id := extracted_id;
				RETURN NEW;
			END IF;
		END IF;

		IF host = 'discogs.com' THEN
			extracted_id := (regexp_matches(path, '/(release|master)/(\d+)', 'i'))[2];
			IF extracted_id IS NOT NULL THEN
				NEW.provider := 'discogs';
				NEW.media_id := extracted_id;
				RETURN NEW;
			END IF;
		END IF;

		IF host = 'soundcloud.com' OR host = 'm.soundcloud.com' THEN
			segments := regexp_split_to_array(trim(both '/' from path), '/');
			IF array_length(segments, 1) >= 2 THEN
				username := segments[1];
				IF username NOT IN ('discover', 'stream', 'upload', 'you', 'search',
					'charts', 'messages', 'settings', 'notifications', 'people',
					'terms-of-use', 'pages') THEN
					NEW.provider := 'soundcloud';
					NEW.media_id := trim(both '/' from path);
					RETURN NEW;
				END IF;
			END IF;
		END IF;

		-- Direct media file URLs (aligned with media-now parseFile extensions)
		IF url_text ~* '\\.(mp3|m4a|aac|mid|midi|ogg|oga|wav|flac|opus|weba|mp4|webm|ogv)(?:$|[?#])'
			OR path ~* '\\.(mp3|m4a|aac|mid|midi|ogg|oga|wav|flac|opus|weba|mp4|webm|ogv)$' THEN
			NEW.provider := 'file';
			NEW.media_id := url_text;
			RETURN NEW;
		END IF;

		RETURN NEW;
	END;
$function$;

-- Backfill unresolved rows while preserving existing updated_at values.
ALTER TABLE tracks DISABLE TRIGGER track_update;
UPDATE tracks
SET url = url
WHERE provider IS NULL OR media_id IS NULL;
ALTER TABLE tracks ENABLE TRIGGER track_update;
