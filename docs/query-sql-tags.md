# Querying R4 track tags with PostgreSQL Arrays

In PostgreSQL, you can store arrays in a column. This is useful for storing tags or categories associated with a record. We use this technique for the track tags on Radio4000 v2. Here's a quick guide on how to query arrays in PostgreSQL. You'll use the operators `@>` and `&&`.

## Querying for a Single Tag

To query for a single tag, use the `@>` operator:

```sql
SELECT * FROM tracks WHERE tags @> '{latin}'
```

## Querying for Multiple Tags

To query for multiple tags, use the `&&` operator:

```sql
SELECT * FROM tracks WHERE tags && '{tag1,tag2,tag3}'
```

## Excluding Tags

To exclude tags, use the `NOT` operator along with the `@>` operator:

```sql
SELECT * FROM tracks WHERE NOT tags @> '{tag}'
```

## Querying for "Has X but not Y"

To query for records that have tag X but not tag Y, combine the `@>` and `NOT` operators:

```sql
SELECT * FROM tracks WHERE tags @> '{tagX}' AND NOT tags @> '{tagY}'
```
