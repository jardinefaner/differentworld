---
name: space-id-everywhere
description: Every synced table carries a `space_id` column. RLS and sync rules gate on it. Triggered when scaffolding any new synced table.
---

# Every synced table has `space_id`

This is the load-bearing invariant of the multi-tenancy model.

## Migration

```sql
create table public.foos (
  id        uuid primary key default gen_random_uuid(),
  space_id  uuid not null references public.spaces(id) on delete cascade,
  -- ...
);
```

## Sync rule

```yaml
- SELECT * FROM foos WHERE space_id IN (SELECT space_id FROM members WHERE id = auth.user_id())
```

Single-column gate. RLS policies join inside (slow), subquery sync
rules get ugly, but a single-column eq is conflict-free.

## Drift class

```dart
class Foos extends Table {
  TextColumn get id => text()();
  TextColumn get spaceId => text()();  // never nullable, never missing
  // ...
}
```

## Why not join through another entity

Tempting: "this row belongs to a Group, which belongs to a Space —
join through groups in the sync rule." Don't.

- Joins make the sync stream slow at scale
- RLS policies that join produce "infinite recursion" errors
- Soft-deleting a group orphans rows in unclear states

Single column. Every table. Yes including the table that already has
`group_id` (just add `space_id` too).

## The one exception

`members.space_id` is `nullable` because a brand-new user hasn't joined
a space yet — that's the "no space" state the router gates on for
`JoinOrCreateScreen`. Every OTHER table has `space_id NOT NULL`.
