---
name: new-migration
description: Create a timestamped SQL migration in supabase/migrations/ with the standard structure. Triggered when adding a column, function, policy, or table.
---

# /new-migration — timestamped SQL file

## Naming

`supabase/migrations/YYYYMMDDHHMMSS_short_name.sql`

Match the existing timestamp prefix scheme — the next number after the
last migration. Today's date in `YYYYMMDD` + a sequence number when
adding multiple in a day. See `ls supabase/migrations/ | tail`.

## Template

```sql
-- ---------------------------------------------------------------------------
-- One-line summary of what this migration does.
--
-- Why: longer explanation. What problem it solves, what's the user-facing
-- change, any non-obvious decisions.
-- ---------------------------------------------------------------------------

-- ... SQL goes here

-- If adding helper functions, they live in the `app` schema so PostgREST
-- doesn't auto-expose them. Lock the search_path:
--
--   create or replace function app.foo()
--   returns ...
--   language sql
--   security definer
--   set search_path = ''
--   as $$
--     -- fully qualify everything: public.members, not just members
--   $$;
--
--   grant execute on function app.foo() to authenticated;

-- If adding RLS policies, use the relaxed form (CLAUDE.md gotcha):
--
--   create policy "foos_authenticated_all" on public.foos
--     for all to authenticated
--     using (true) with check (true);
```

## After writing

Run `/push-db`. If the migration changed a synced table's structure,
follow the `new-table` checklist for the other 4 places.

## Patterns that come up

- Adding a column to existing table: `alter table public.foos add column ...`
  then update `power_sync_schema.dart`, `app_database.dart`, regen,
  wipe local DB.
- Adding an RPC: see `public.accept_invite` in migration
  `20260518000002_accept_invite_rpc_wrapper.sql` for the pattern.
- Storage bucket: see `20260518000003_person_photos_bucket.sql`.
