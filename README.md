# supabase configuration for Radio4000 deployment
This repository helps setup and maintain a Radio4000 project. The database can
either run on the hosted Supabase platform, or you can use your own
server.

## Usage
1. create a new supabase instance (locally, on premise or on supabase)
2. for this repository
3. connect the supabase instance to this repository's `prod` branch,
   for the latest latest version, ready for "prodution"
4. pull changes from this project upstream fork to get changes
5. all new commits are deployed as database migrations by supabase

## How it works
The `supabase/` folder contains an initial project created with `npx
supabase bootsrap`.

Insite it, the `migrations/` folder contains the sql configuration for
the database, that are automatically run by supabase/github connection
on push.

## With Supabase platform (sass, free, pay-as-you-go)

If you are ok using the offered Supabase hosting.

1. Create a new project on [app.supabase.io](https://app.supabase.io)
2. Import the [radio4000.sql](https://github.com/radio4000/supabase/blob/main/radio4000.sql) SQL schema

```shell
DATABASE_URL = postgres://postgres:[DB_PASSWORD]@[HOST]:6543/postgres
psql $DATABASE_URL -f radio4000.sql
```

That's it. Now you have an empty PostgreSQL database set up to work for Radio4000. What now?

- You could build your own thing!
- See the [radio4000/cms](https://github.com/radio4000/cms) project

## Self-hosting

See the guide to [self-hosting with Supabase](https://github.com/radio4000/supabase/blob/main/self-hosting.md).

## Tips

### Supabase Auth

Set the Site URL and Redirect URLs under Authentication -> URL Configuration on app.supabase.io.

### API Limit

By default database queries return a maximum of 1000 rows. Change this under Settings > API -> "Max Rows" on app.supabase.io.

### Connect to database with `psql`

Using the cli `psql`, we can connect to any postgres database.  
Find the connection string under your Supabase project's settings -> Database.

```
psql postgres://postgres:postgres@localhost:5432/postgres
```

## References

- https://supabase.com/docs/architecture
- https://supabase.io/docs/reference/cli/getting-started
- https://github.com/supabase/cli
- https://supabase.io/new/blog/2021/03/31/supabase-cli
