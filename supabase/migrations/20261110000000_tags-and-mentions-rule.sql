-- Tags and mentions follow the rules Twitter and Bluesky settled on:
--
-- Start: '#' or '@' at the start of the text or after anything that isn't a
-- letter, digit, '_', '&' or '/' (twitter-text). So "#techno", "(#uk)",
-- '"#balearic' and "nice...#chillhop" count; "page#top", "info@shop.com",
-- "&#39;", "site.com/#about" and "youtube.com/@ko002" don't. Bluesky only
-- allows whitespace before, which drops ~100 real tags here.
--
-- Tag body: runs to the next whitespace or '#', so "#rone#2012" gives "rone"
-- and "#a,#b" gives both, with trailing punctuation cut (Bluesky). Unlike
-- Bluesky, all-digit tags like #1994 are kept; they're how people tag years.
--
-- Mention body: a channel slug, so only letters, digits, '_' and '-' (Twitter
-- does the same for usernames). "@alice's" is "alice"; slugs like "rádio" work.
--
-- Both: lowercased, deduplicated, sorted, at most 64 characters.
--
-- Plain string steps rather than one big regex, so the rule reads the same
-- here and in the sdk's JavaScript copy. Punctuation and whitespace are
-- spelled out, because [[:punct:]] depends on the database locale: production's
-- C.UTF-8 counts '+' and '=', which would turn "#c++" into "c".
--
-- Before, '#(\S+)' matched anywhere and kept punctuation, so "#techno," stored
-- "techno,", "page#top" in a link stored "top", and "info@shop.com" stored a
-- mention. Descriptions are not touched; only the derived columns change.

create or replace function "public"."parse_tokens"("content" "text", "prefix" "text") returns "text"[]
	language "plpgsql"
	immutable
	set "search_path" to 'pg_catalog', 'public'
	as $$
declare
	-- Whitespace, including no-break and zero-width spaces and line separators.
	spaces constant text := E' \t\n\u000b\f\r\u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u200b\u200c\u200d\u2028\u2029\u202f\u205f\u2060\u3000\ufeff';
	-- Cut from the end of a tag.
	cut_chars constant text := $c$!"#%&'()*,./:;?@[\]{}¡§«»¿‐‑‒–—―‖‗‘’‚‛“”„‟†‡•‣․‥…‧、。〈〉《》「」『』【】！（），．：；？＠［］｛｝-$c$;
	piece text;
	before text;
	token text;
	tokens text[] := '{}'::text[];
begin
	if prefix is distinct from '#' and prefix is distinct from '@' then
		return '{}'::text[];
	end if;
	-- Split at every sign. Each piece after the first starts right after a sign,
	-- and the character before that sign is the last one of the previous piece.
	before := null; -- the first piece comes before any sign
	foreach piece in array string_to_array(lower(coalesce(content, '')), prefix) loop
		-- A sign counts at the start or after whitespace or punctuation, but not
		-- after a letter, digit, '_', '&' or '/' ("page#top", "info@shop.com",
		-- "&#39;", "youtube.com/@ko002").
		if before = '' or position(before in spaces) > 0
			or (before !~ '[[:alnum:]_]' and before not in ('&', '/')) then
			if prefix = '#' then
				-- Up to the first whitespace, trailing punctuation cut.
				token := rtrim(split_part(translate(piece, spaces, repeat(' ', length(spaces))), ' ', 1), cut_chars);
			else
				-- A channel slug: letters, digits, '_' and '-'.
				token := substring(piece from '^[[:alnum:]_-]+');
			end if;
			if token <> '' and char_length(token) <= 64 then
				tokens := tokens || token;
			end if;
		end if;
		before := coalesce(right(piece, 1), '');
	end loop;
	return coalesce((select array_agg(distinct t order by t) from unnest(tokens) t), '{}'::text[]);
end;
$$;

-- Recompute tags and mentions for the tracks whose result changes. The
-- update_tags trigger does the parsing and update_tags_counts keeps the tags
-- table right. track_update is paused so updated_at keeps meaning "edited by
-- someone"; clients compare it to decide whether their cache is stale.
alter table "public"."tracks" disable trigger "track_update";

update "public"."tracks"
set description = description
where not (coalesce(tags, '{}') @> parse_tokens(description, '#') and coalesce(tags, '{}') <@ parse_tokens(description, '#'))
	or not (coalesce(mentions, '{}') @> parse_tokens(description, '@') and coalesce(mentions, '{}') <@ parse_tokens(description, '@'));

alter table "public"."tracks" enable trigger "track_update";

-- Search filters on mentions now (`mentions @> '{ko002}'`), like tags since
-- 20261020000000; without this it's a full scan of tracks.
create index if not exists "tracks_mentions_gin" on "public"."tracks" using "gin" ("mentions");
