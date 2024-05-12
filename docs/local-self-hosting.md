# Local, self-hosted Supabase with Docker

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

When you develop locally, all the emails related to user authentication ARE NOT SENT. Instead, what would potentially have been sent are displayed in a local software called @inbucket on http://127.0.0.1:54324/monitor.

> Note, if no server is available at this address, the local `supabase` server is most probably not running. Check with `supabase status`.

