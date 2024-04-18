# Radio4000 supabase docs

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

## References

- https://supabase.com/docs/architecture
- https://supabase.io/docs/reference/cli/getting-started
- https://github.com/supabase/cli
- https://supabase.io/new/blog/2021/03/31/supabase-cli
