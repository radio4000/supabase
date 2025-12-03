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
