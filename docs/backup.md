# Backup & Restore

## Backup

Run `./scripts/backup-production-database.sh` to create backups.

This creates timestamped files in `./backups/`:
- `_schema.sql` - database structure (tables, views, functions, RLS)
- `_data.sql` - all data (includes both `public.*` and `auth.*` tables)

## Restore

To restore to a new Supabase project:

1. Create a new project and get the connection string from the Connect button
2. Enable any extensions/webhooks used in the old project
3. Run:

```bash
psql \
  --single-transaction \
  --variable ON_ERROR_STOP=1 \
  --file backups/backup_TIMESTAMP_schema.sql \
  --command 'SET session_replication_role = replica' \
  --file backups/backup_TIMESTAMP_data.sql \
  --dbname "CONNECTION_STRING"
```

Note: If you get permission errors about `supabase_admin`, comment out those lines in the schema file.

See the official Supabase docs for more details:
https://supabase.com/docs/guides/platform/migrating-within-supabase/backup-restore#restore-backup-using-cli
