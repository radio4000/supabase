# Self-hosted Supabase with Docker

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

```
psql <DATABASE_URL> -f radio4000.sql
```

## Tips

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

### Eject app (do not)

Do not eject the app with `supabase eject`; just like `create-react-app` in the frontend,
we're happy to get the supabase cli updates.

