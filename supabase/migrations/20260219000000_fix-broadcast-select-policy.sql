-- Fix: broadcast table wasn't readable for anon users.
-- The old policy didn't specify roles, so anon couldn't read broadcasts.
DROP POLICY IF EXISTS "Broadcasts are viewable by everyone" ON public.broadcast;
DROP POLICY IF EXISTS "Broadcasts are publicly readable" ON public.broadcast;

CREATE POLICY "Broadcasts are publicly readable"
ON public.broadcast
FOR SELECT
TO anon, authenticated
USING (true);
