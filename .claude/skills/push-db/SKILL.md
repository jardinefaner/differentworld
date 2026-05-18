---
name: push-db
description: Push the latest Supabase migration via the CLI. The user has pre-authorized this (Bash permission). Triggered after writing a new SQL migration.
---

# /push-db — supabase db push

```bash
supabase db push
```

The user has explicitly granted `Bash(supabase db push:*)` so you can
run this directly without handing it back. The CLI's own Y/N prompt
is the user's checkpoint.

## Before you push

- Verify the migration is in `supabase/migrations/` with a
  timestamped name matching the convention
  `YYYYMMDDHHMMSS_short_name.sql`
- Check it doesn't drop columns / tables that PowerSync still references
- Confirm if PowerSync sync rules also need updating (then see
  `sync-add-table`)

## After you push

If the migration changed table structure or added a new synced table:

1. Update `supabase/sync_rules.yaml` if needed
2. Tell the user to **redeploy sync rules in the PowerSync dashboard**
   — the repo file is source of truth, the dashboard is runtime
3. Update `lib/core/db/power_sync_schema.dart`
4. Update `lib/core/db/app_database.dart`
5. Run `/regen`
6. Tell the user to `/wipe-pixel` on every active device

## Common errors

- `relation "X" already exists` — earlier migration partial-applied;
  you may need to manually clean state in the Supabase Dashboard SQL
  editor
- `permission denied for table X` — GRANT-level missing; see
  CLAUDE.md gotcha block on grants
- `auth.uid() is null in policy` — the JWT-claims gotcha; use the
  `current_user = 'authenticated'` workaround
