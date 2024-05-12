# Connect to database with `psql`

Using the cli `psql`, we can connect to any postgres database.  

Find the connection string under your Supabase project's settings -> Database.

```
psql postgres://postgres:postgres@localhost:5432/postgres
DATABASE_URL = postgres://postgres:[DB_PASSWORD]@[HOST]:6543/postgres
psql $DATABASE_URL -f supabase/migrations/*.sql
```

Now there is an empty PostgreSQL database with the correct schemas,
setup to work for Radio4000.

## Backup

Do not forget that this is PostgreSQL. The usual methods like `pg_dump` and [`pg_dumpall`](https://www.postgresql.org/docs/current/app-pg-dumpall.html) will work. That being said, the Supabase CLI makes it easier to run.

By default it'll attempt to connect to your _linked_, remote Supabase project. It will ask for the db password. If no project is linked, run `supabase link`.

```
supabase db dump -f supabase/schema.sql
supabase db dump -f supabase/roles.sql --role-only
supabase db dump -f supabase/seed.sql --data-only 
```

To connect to your local set up, use the `--local` flag.

- https://supabase.com/docs/reference/cli/supabase-db-dump
- https://supabase.com/docs/guides/platform/backups
