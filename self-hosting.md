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

Run `make import`. It will pull the required the SQL files in this repo and run them on the local database. Make sure the database is running.

