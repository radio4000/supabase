To take a backup rely on `pg_dump` or the Supabase CLI.

Our own `./scripts/backup-production-database.sh` script will link
the repo to a remote Supabase and save a backup sql file.
