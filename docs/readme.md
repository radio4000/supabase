# Radio4000 supabase docs

1. create a new supabase instance (locally, on premise or on supabase)
2. fork this repository
3. link the supabase instance with `supabase link`
4. pull changes from this project upstream fork to get changes
5. deploy new migrations with `supabase db push --remote`

## How it works

The `supabase/` folder contains an initial project created with `npx
supabase bootstrap`.

Inside it, the `migrations/` folder contains the sql configuration for
the database, deployed with `supabase db push --remote`.

## References

- https://supabase.com/docs/architecture
- https://supabase.com/docs/reference/cli/getting-started
- https://supabase.com/docs/guides/database/overview
