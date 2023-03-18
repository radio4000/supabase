# radio4000-supabase

The **Supabase** configuration for Radio4000. 

This repository will help you set up a working backend for Radio4000. The database can either run on the hosted Supabase platform, or you can use your own server.

Later we'd like to help with

- putting a new version to production
- maybe future supabase functions/workers

## With Supabase platform (sass, free, pay-as-you-go)

If you are ok using the offered Supabase hosting.

1. Create a new project on [app.supabase.io](https://app.supabase.io)
2. Import the [04-radio4000.sql](https://github.com/radio4000/supabase/blob/main/04-radio4000.sql) SQL schema

```shell
# Find the connection string under Supabase project settings -> Database.
DATABASE_URL = postgres://postgres:[DB_PASSWORD]@[HOST]:6543/postgres
psql $DATABASE_URL -f 04-radio4000.sql
```

That's it. Now you have an empty PostgreSQL database set up to work for Radio4000. What now?

- You could build your own thing!
- See the [radio4000/cms](https://github.com/radio4000/cms) project

## Self-hosted

See the guide to [self-hosting with Supabase](https://github.com/radio4000/supabase/blob/main/self-hosted.md).

## Tips

### API Limit

By default the database is set to return max 1000 rows. You can change this under Settings > API on app.supabase.io.

### Local development server (npx/docker/docker-compose)

In the project's directory, you can run the following commands to run
all the supabase components, in a local docker/docker-compose environment.

- `npx supabase start` will start the local development server

> You should go for the default *ports* (when prompted, for all the
> supabase services), or have a reason to change them.

> Note: if you already have a local postgresql running, you might run
> into port conflicts, and this command could fail. In case, stop
> other postgresql instance running, or take care of conflicting ports.

- `npx supabase stop` will stop the local development server

### Connect to database with `psql`

Using the cli `psql`, we can connect to the local dabase (which runs in docker)

```
psql <postgres_url>
```

By default:
- `<postgres_url>` = `postgres://postgres:postgres@localhost:5432/postgres`

### Eject app (do not)

Do not eject the app with `supabase eject`; just like `create-react-app` in the frontend,
we're happy to get the supabase cli updates.

## Deploying

@todo

## User authentication (emails)

The local development server (supabase backend), allows to `signUp`
(register) and `signIn` (login) new users (also `signOut`).

Since these actions **send emails**,no mail will be sent to the "real
email" used to register locally, but mails are displayed in a local
web server/interface.

# about supabase

- https://supabase.com/docs/architecture

The local "webmail" (provided by the supabase setup) is availabale at
[http://localhost:9000/](http://localhost:9000/).

It allows to click the user validating link, for all email
adresses that have been used to register.

> Note, if no server is available at this local address, is is most
> probably because you are not running the local supabase server (see
> above)

## References

- https://supabase.io/docs/reference/cli/getting-started
- https://github.com/supabase/cli
- https://supabase.io/new/blog/2021/03/31/supabase-cli
