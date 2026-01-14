# Reserved channel slugs

Radio4000 has channel "slugs" at the root URL e.g. `/<slug>`. To prevent conflicts with our applications we reserve certain slugs.

- Reserved channel "slugs" are stored in the `reserved_slugs` table.
- A database trigger checks this table whenever a channel is created or its slug is updated.
- If the slug matches a reserved one, the operation is rejected.

## Managing reserved slugs

```sql
-- Add a reserved slug
INSERT INTO reserved_slugs (slug) VALUES ('newslug');

-- Remove a reserved slug
DELETE FROM reserved_slugs WHERE slug = 'oldslug';

-- View all reserved slugs
SELECT * FROM reserved_slugs;
```

