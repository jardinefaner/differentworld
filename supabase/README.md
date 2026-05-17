# Supabase + PowerSync schema

This directory is the source of truth for the **backend** side of Different
World. The Flutter app's Drift schema (under `lib/core/db/`) must stay in
sync with these files.

## Layout

```
supabase/
  migrations/        # Postgres migrations — apply in filename order
    20260515000001_foundation.sql              programs, profiles, classrooms, enrollments
    20260515000002_roster.sql                  students, guardians, student_guardians
    20260515000003_attendance.sql              attendance_records
    20260515000004_powersync_publication.sql   replica identity + powersync publication
  sync_rules.yaml    # PowerSync sync rules — paste into the PowerSync dashboard
```

## Applying the migrations

Pick one of two paths.

### Option A — Supabase dashboard (fastest for v1)

For each `.sql` file, in order:

1. Open your Supabase project → **SQL Editor** → **New query**.
2. Paste the file contents, run.
3. Verify the tables appear in **Table Editor** with RLS enabled (lock icon).

### Option B — Supabase CLI (recommended once you have more than two migrations)

```sh
brew install supabase/tap/supabase
supabase login
supabase link --project-ref <your-project-ref>
supabase db push
```

The CLI tracks which migrations have been applied via the
`supabase_migrations.schema_migrations` table.

## Wiring PowerSync

1. Sign up at https://www.powersync.com and create an instance.
2. **Apply all four migrations to Supabase first** — including
   `20260515000004_powersync_publication.sql`, which creates the
   `powersync` publication that PowerSync tails. Without that publication,
   step 4 fails with `Publication 'powersync' not found`.
3. In the PowerSync dashboard, connect the instance to your Supabase Postgres:
   - Use the **direct connection** (port 5432, host `db.<ref>.supabase.co`),
     not the pooler (port 6543).
   - Database name in URI is `postgres`.
   - Supabase already runs with `wal_level = logical`; nothing to toggle.
4. Configure **client auth** in PowerSync: select Supabase as the provider
   and paste the **JWT secret** (Supabase → Project Settings → API → JWT
   Settings → JWT Secret). This is *not* the anon key.
5. Open **Sync Rules** for the instance, paste the contents of
   `sync_rules.yaml`, validate, deploy.
6. Copy the **Instance URL** into your `.env` as `POWERSYNC_URL`.

### Adding a new synced table later

Every synced table must be wired in three places — miss any and it
silently won't sync:

1. A SQL migration that creates the table and sets
   `alter table public.<name> replica identity full;`
2. `alter publication powersync add table public.<name>;`
3. A new `SELECT * FROM <name> WHERE program_id IN (...)` line in the
   `by_program` stream of `sync_rules.yaml`, then re-deploy in the
   PowerSync dashboard.

`sync_rules.yaml` uses PowerSync's **edition 3 streams** format. The
older `bucket_definitions` format also works but is being phased out;
new tables should be added to the streams.

## Design conventions

These are load-bearing — break them and resync gets ugly.

- **Every synced table carries `program_id`**, even when it would naturally
  be derived through a join. This makes RLS policies and PowerSync data
  queries single-column comparisons (fast, simple, conflict-free).
- **IDs are `uuid` server-side, `text` client-side.** PowerSync handles the
  conversion. Generate IDs client-side with the `uuid` package so offline
  writes have stable PKs that survive sync.
- **`updated_at` is bumped by trigger**, never set from the client. Clients
  read it but don't write it.
- **No cascading deletes from `profiles`** for content tables — set the
  reference to null instead (`recorded_by`). A staff member leaving
  shouldn't delete history.
- **Role checks live in `current_program_id()` / `is_director()`** helper
  functions, not inline in every policy. Cheaper to change later.

## What's intentionally missing (yet)

- **Photos / Supabase Storage buckets** — added in Phase 5 when we wire
  observations.
- **Day plans, activities, curriculum, schedules, trips** — added per
  feature slice in Phase 6.
- **Surveys** — Phase 7.
