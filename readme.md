# radio4000-supabase

The **supabase** configuration for radio4000-cms.

It is aimed at simplifying:
- local development (of radio4000 cms, and other projects using the
  api or database schema).
- putting a new version to production
- migrate an instance to a newer version (of the postgres db)
- (maybe future supabase function)

Docs:

- https://supabase.io/new/blog/2021/03/31/supabase-cli
- https://github.com/supabase/cli

# Initial setup

Clone and init the project locally.

You have to do this setup only once, *don't forget to write project keys down* at the end of the init.

```
git clone git@github.com:internet4000/radio4000-supabase
cd radio4000-supabase
```

The init command will create a `./.supabase` folder, with the docker
config of everything needed to run the local development server.

> This project folder should never be commited to a repository (it is
> in .gitignore).

```
npx supabase init
```

The init command should have outputed some logs, such as:
```
Supabase URL: <supabase_url>
Supabase Key (anon, public): <supabase_anon_key>
Supabase Key (service_role, private): <supabase_service_role_key>
Database URL: <postgres_url>
Email testing interface URL: <email_url>
```

> Write down this information, for example in your password manager's
> notes. It is only provided when doing a new project init

The values of `<supabase_url>`, and `<supabase_anon_key>`, should be the one used in the [radio4000-cms]() project.

> Use them to replace the values of the project
> `radio4000-cms`, inside the `/.env` file, to connect the frontend to
> this project. You will also need to run the local supabase development server for this.

# local development server

In the project's directory, you can run the following commands to run
all the supabase components, in a local docker/docker-compose
environment.

- `npx supabase start` will start the local development server

> You should go for the default *ports* (when prompted, for all the
> supabase services), or have a reason to change them.

- `npx supabase stop` will stop the local development server

# eject app (do not)

Do not eject the app with `supabase eject`; just like
`create-react-app` in the frontend, we're happy to get the supabase
cli updates.
