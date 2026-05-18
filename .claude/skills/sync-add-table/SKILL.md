---
name: sync-add-table
description: Reference for the full 12-step sequence when adding or renaming a synced table — the longer version of new-table.
---

# /sync-add-table — the full 12-step

For renames or any non-trivial schema change. Skip if you're adding a
single column to an existing table (use `add-drift-column` instead).

1. **Write the migration SQL** (`supabase/migrations/<ts>_<name>.sql`)
2. **Update `lib/core/db/power_sync_schema.dart`** to match
3. **Update `lib/core/db/app_database.dart`** (Drift classes) to match
4. **Update every consumer in `lib/`** that uses the old name
5. **`supabase db push`** — apply server-side (we have `Bash` permission
   for this command pre-granted)
6. **Update `supabase/sync_rules.yaml`** in the repo
7. **PASTE the new sync rules into the PowerSync dashboard and hit
   Deploy.** Source of truth is repo, runtime is dashboard. Forgetting
   this leaves PowerSync's queries pointing at the old (now
   non-existent) tables. The sync "succeeds" with zero rows; the app
   sits forever on its loading spinner with no error in logs.
8. **`dart run build_runner build`** — regenerate `.g.dart` files
9. **`flutter clean && flutter pub get`** — wipe build cache
10. **`flutter analyze`** — confirm zero issues
11. **`flutter test`** — confirm passing
12. **Tell the user to clear local storage on every active device**
    (uninstall on mobile, clear site data on web). Local SQLite needs
    to recreate itself with the new schema.

## Symptoms of skipped steps

| Skipped step | Symptom |
|---|---|
| 1 | "table X does not exist" on Supabase |
| 2-3 | Drift query errors, "no such column" on local SQLite |
| 5 | "table X does not exist" but only on uploads |
| 6 | Sync rules drift between repo and dashboard |
| 7 | "Validated and applied checkpoint" with 0 rows downloading forever |
| 8 | Stale `.g.dart` references to old class names |
| 12 | App stuck on "Syncing your profile…" or empty tables |

## If symptoms are "Validated and applied checkpoint" but no
"downloading: true" line and local tables are empty when you query them,
**step 7 is the culprit 99% of the time**.
