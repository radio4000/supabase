CREATE TABLE reserved_slugs (
  slug TEXT PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seed initial reserved slugs
INSERT INTO reserved_slugs (slug) VALUES
  ('about'),
  ('account'),
  ('add'),
  ('admin'),
  ('api'),
  ('app'),
  ('assets'),
  ('auth'),
  ('beta'),
  ('blog'),
  ('broadcasts'),
  ('cdn'),
  ('channel'),
  ('channels'),
  ('contact'),
  ('create-channel'),
  ('css'),
  ('dashboard'),
  ('debug'),
  ('dev'),
  ('docs'),
  ('download'),
  ('email'),
  ('embed'),
  ('empty'),
  ('explore'),
  ('faq'),
  ('favorites'),
  ('feed'),
  ('following'),
  ('health'),
  ('help'),
  ('history'),
  ('home'),
  ('images'),
  ('index'),
  ('js'),
  ('login'),
  ('logout'),
  ('mail'),
  ('map'),
  ('mobile'),
  ('music'),
  ('new'),
  ('news'),
  ('null'),
  ('ping'),
  ('player'),
  ('playlist'),
  ('privacy'),
  ('private'),
  ('profile'),
  ('public'),
  ('queue'),
  ('radio'),
  ('recovery'),
  ('robots'),
  ('rss'),
  ('search'),
  ('settings'),
  ('sign'),
  ('signup'),
  ('sitemap'),
  ('staging'),
  ('static'),
  ('stats'),
  ('status'),
  ('support'),
  ('terms'),
  ('test'),
  ('track'),
  ('tracks'),
  ('undefined'),
  ('user'),
  ('users'),
  ('widget'),
  ('www')
;

-- Function to check against reserved_slugs table
CREATE OR REPLACE FUNCTION check_reserved_slug()
RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM reserved_slugs WHERE slug = NEW.slug) THEN
    RAISE EXCEPTION 'Slug "%" is reserved', NEW.slug;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger on channels table
CREATE TRIGGER prevent_reserved_channel_slug
BEFORE INSERT OR UPDATE OF slug ON channels
FOR EACH ROW EXECUTE FUNCTION check_reserved_slug();
