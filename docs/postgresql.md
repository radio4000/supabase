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
