# Database migration

When we are updating the schema of the database tables, we want to run migrations.

Supabase ([docs](https://supabase.com/docs/guides/deployment/database-migrations)) explains how to do that using their CLI.

```bash
npx supabase migration new <migration_name>
# creates an empty migration file locally, in the folder `./supabase/migrations/<timestamp>_<migration_name>.sql`
```

When the migration file is filled with the sql instructions, we can run:

```bash
# Run this migration in a "local" database
supabase migration up

# push the migrations to a "remote" database
supabase db push
```

## How to test migrations locally

1. Verify Docker: `docker info > /dev/null 2>&1 && echo "running" || echo "not running"`
2. If not running → ask user to start it (don't start it yourself)
3. Start Supabase: `bunx supabase start`
4. Apply migrations: `bunx supabase db reset` (or `bunx supabase migration up`)
5. Test your changes with docker exec psql

Local DB: `postgresql://postgres:postgres@127.0.0.1:54322/postgres`

