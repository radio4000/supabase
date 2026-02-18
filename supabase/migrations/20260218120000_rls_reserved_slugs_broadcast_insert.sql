-- reserved_slugs: enable RLS, read-only lookup table
ALTER TABLE reserved_slugs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Reserved slugs are viewable by everyone"
  ON reserved_slugs FOR SELECT
  USING (true);
