# Self-hosted Supabase with Docker

If you want to host your own Supabase instance, you can do it. This is how. You have to do this setup only once. 

## Quick guide

1. Install [Docker Desktop](https://www.docker.com/products/docker-desktop/) on your computer
2. Clone the R4 Supabase repository locally `git clone git@github.com:radio4000/supabase`
3. Run `npx supabase start`

This start command will install the things locally on your machine via Docker,
and run any migration files in `./supabase/migrations` folder. Finally it'll output the keys you need. Make sure to save these somewhere. They are only shown once.

To use the [@radio4000/sdk](https://github.com/radio4000/sdk), you will need at least two keys: 

- The `API URL` is the `Supabase URL` (usually `http://127.0.0.1:54321`)
- The `anon key` is the the `Supabase Anon Key` (usually `eyJ...`)

## Tips

- `npx supabase stop` will stop the local development server
- `npx supabase status` shows useful status info
- Run an .sql file on the database: `psql <DATABASE_URL> -f radio4000.sql`

### User authentication (emails)

The local development server (supabase backend), allows to `signUp`
(register) and `signIn` (login) new users (also `signOut`).

Since these actions **send emails**,no mail will be sent to the "real
email" used to register locally, but mails are displayed in a local
web server/interface.

The local "webmail" (provided by the supabase setup) is available at
[http://localhost:9000/](http://localhost:9000/).

It allows to click the user validating link, for all email
adresses that have been used to register.

> Note, if no server is available at this local address, is is most
> probably because you are not running the local supabase server (see
> above)

