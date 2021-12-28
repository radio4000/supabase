# radio4000-supabase

The **Supabase** configuration for Radio4000. 

This repository will help you set up a working backend for Radio4000. The database can either run on the hosted Supabase offering or you can use your own server.

Later we'd like to help with

- putting a new version to production
- maybe future supabase functions/workers

### With Supabase platform (sass, free, pay-as-you-go)

If you are ok with using the offered Supabase hosting.

1. Login to [app.supabase.io](https://app.supabase.io)
2. Go to the `> sql` page to write a new sql query
3. Copy the content from the file [04-radio4000.sql](https://github.com/internet4000/radio4000-supabase/blob/main/04-radio4000.sql), and run it on
   supabase (in the page from the step above)
4. If it worked, it should return no error to the query

That's it.

See the [radio4000-cms](https://github.com/internet4000/radio4000-cms) project.

### Self-hosted Supabase with Docker

If you want to host your own Supabase instance, you can do it. This is how. You have to do this setup only once. 

### 1. Install docker and clone this repo

1. Install `docker-compose` on your computer
1. Clone the project locally `git clone git@github.com:internet4000/radio4000-supabase`

### 2. Run supabase init

```
npx supabase init
```

The init command will create a `./.supabase` folder, with the docker
config of everything needed to run the local development server.

> The ".supabase" folder is in .gitignore and should not be commited to a repository

The init command will output logs such as:

```
Supabase URL: <supabase_url>
Supabase Key (anon, public): <supabase_anon_key>
Supabase Key (service_role, private): <supabase_service_role_key>
Database URL: <postgres_url>
Email testing interface URL: <email_url>
```

Write down this information, for example in your password manager's notes. It is only provided once.

The values of `<supabase_url>` and `<supabase_anon_key>` you will need to run the [radio4000-cms](https://github.com/internet4000/radio4000-cms) project.

### 3. Set up up the database schemas

Run `make`. It will pull the required the SQL files in this repo and run them on the local database. Make sure the database is running.

## More tips

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

Do not eject the app with `supabase eject`; just like
`create-react-app` in the frontend, we're happy to get the supabase
cli updates.


## production hosting/deploy

## User authentication (emails)

The local development server (supabase backend), allows to `signUp`
(register) and `signIn` (login) new users (also `signOut`).

Since these actions **send emails**,no mail will be sent to the "real
email" used to register locally, but mails are displayed in a local
web server/interface.

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
