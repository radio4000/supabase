# Local, self-hosted Supabase with Docker

If you want to host your own Supabase instance, you can do it. This is how. You have to do this setup only once. 

## Quick guide

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) on your computer
2. Clone the R4 Supabase repository locally `git clone git@github.com:radio4000/supabase`
3. Run `bunx supabase start`

This start command will install the things locally on your machine via Docker,
and run any migration files in `./supabase/migrations` folder. Finally it'll output the keys you need. Make sure to save these somewhere. They are only shown once.

To use the [@radio4000/sdk](https://github.com/radio4000/sdk), you will need at least two keys: 

- The `API URL` is the `Supabase URL` (usually `http://127.0.0.1:54321`)
- The `anon key` is the the `Supabase Anon Key` (usually `eyJ...`)

## Tips

- `bunx supabase stop` will stop the local development server
- `bunx supabase status` shows useful status info

## Connecting to the database

The local database runs on `postgresql://postgres:postgres@127.0.0.1:54322/postgres`.

If you have `psql` installed:

```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres
```

If you don't have `psql`, use docker exec:

```bash
# Find the postgres container name
docker ps --format "{{.Names}}" | grep db

# Interactive psql session
docker exec -it supabase_db_radio4000-supabase psql -U postgres

# Run a SQL command
docker exec -it supabase_db_radio4000-supabase psql -U postgres -c "SELECT count(*) FROM tracks;"

# Run a SQL file (note: -i not -it for file input)
docker exec -i supabase_db_radio4000-supabase psql -U postgres < path/to/file.sql
```

For remote/production database connection strings, check your Supabase project settings under Database.

### User authentication (emails)

When you develop locally, all the emails related to user authentication ARE NOT SENT. Instead, what would potentially have been sent are displayed in a local software called @inbucket on http://127.0.0.1:54324/monitor.

> Note, if no server is available at this address, the local `supabase` server is most probably not running. Check with `supabase status`.

## Restore production data locally

To test with real production data locally, follow these steps.

### 1. Ensure PostgreSQL version matches

Check the remote database version and update `supabase/config.toml` to match:

```toml
[db]
major_version = 17
```

### 2. Link to the remote project

```bash
supabase link
```

This pulls the correct container images matching your remote database version.

### 3. Dump data from production

Dump the public schema data and auth schema data separately:

```bash
supabase db dump --data-only -f supabase/prod_data.sql
supabase db dump --data-only --schema auth -f supabase/prod_auth_data.sql
```

### 4. Reset and restore locally

Reset the local database to apply migrations with a clean slate:

```bash
supabase db reset
```

Truncate auth tables to avoid conflicts, then restore auth data first (since public tables have foreign keys to auth.users), then public data:

```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "TRUNCATE auth.audit_log_entries, auth.users, auth.identities, auth.sessions, auth.mfa_amr_claims, auth.one_time_tokens, auth.refresh_tokens CASCADE;"
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -f supabase/prod_auth_data.sql
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -f supabase/prod_data.sql
```

### 5. Verify the restore

```bash
psql postgresql://postgres:postgres@127.0.0.1:54322/postgres -c "SELECT 'auth.users' as tbl, count(*) FROM auth.users UNION ALL SELECT 'channels', count(*) FROM channels UNION ALL SELECT 'tracks', count(*) FROM tracks;"
```

> Note: The dump files contain production data and should not be committed to git. They are already in `.gitignore`.

