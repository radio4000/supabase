# radio4000-supabase

The **supabase** configuration for radio4000-cms.

It is aimed at simplifying:
- local development (of radio4000 cms, and other projects using the
  api or database schema).
- putting a new version to production
- migrate an instance to a newer version (of the postgres db)
- (maybe future supabase function)

Docs:

- https://supabase.io/docs/reference/cli/getting-started
- https://github.com/supabase/cli
- https://supabase.io/new/blog/2021/03/31/supabase-cli

# Initial setup

You have to do this setup only once. You will need `docker-compose` installed on your computer.

1. Clone the project locally:

```
git clone git@github.com:internet4000/radio4000-supabase
cd radio4000-supabase
```

2. Run supabase init

The init command will create a `./.supabase` folder, with the docker
config of everything needed to run the local development server.

```
npx supabase init
```

> This ".supabase" folder should never be commited to a repository (it is in .gitignore).

The init command should have outputed some logs, such as:

```
Supabase URL: <supabase_url>
Supabase Key (anon, public): <supabase_anon_key>
Supabase Key (service_role, private): <supabase_service_role_key>
Database URL: <postgres_url>
Email testing interface URL: <email_url>
```

> Write down this information, for example in your password manager's notes. It is only provided when doing a new project init

The values of `<supabase_url>` and `<supabase_anon_key>`, you will need to run the [radio4000-cms]() project.

> Use them to replace the values of the project
> `radio4000-cms`, inside the `/.env` file, to connect the frontend to
> this project. You will also need to run the local supabase development server for this.

# local development server (npx/docker/docker-compose)

In the project's directory, you can run the following commands to run
all the supabase components, in a local docker/docker-compose environment.

- `npx supabase start` will start the local development server

> You should go for the default *ports* (when prompted, for all the
> supabase services), or have a reason to change them.

> Note: if you already have a local postgresql running, you might run
> into port conflicts, and this command could fail. In case, stop
> other postgresql instance running, or take care of conflicting ports.

- `npx supabase stop` will stop the local development server

# connect to database with `psql`

Using the cli `psql`, we can connect to the local dabase (which runs in docker)

```
psql <postgres_url>

```

By default:
- `<postgres_url>` = `postgres://postgres:postgres@localhost:5432/postgres`


# eject app (do not)

Do not eject the app with `supabase eject`; just like
`create-react-app` in the frontend, we're happy to get the supabase
cli updates.


# production hosting/deploy

## self hosting (own server)

## supabase host (sass, free, pay-as-you-go)

# User authentication (emails)

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
