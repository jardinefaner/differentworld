---
name: add-drift-column
description: Add a column to an existing synced table — migration + PowerSync schema + Drift class + regen + local wipe. Triggered when extending a table.
---

# /add-drift-column — extend an existing table

## 1. Migration

`supabase/migrations/YYYYMMDDHHMMSS_add_foos_<col>.sql`:

```sql
alter table public.foos add column if not exists new_col text;
-- timestamptz / boolean / jsonb as appropriate
```

Run `/push-db`.

## 2. PowerSync local schema

`lib/core/db/power_sync_schema.dart` — add to the Table's column list:

```dart
Table('foos', [
  Column.text('space_id'),
  // ... existing
  Column.text('new_col'),  // TEXT for any string / timestamp / json
]),
```

Remember: PowerSync's local SQLite has only TEXT / INTEGER / REAL. Map
timestamps → TEXT (ISO 8601), booleans → INTEGER (0/1), jsonb → TEXT.

## 3. Drift class

`lib/core/db/app_database.dart`:

```dart
class Foos extends Table {
  // ... existing
  TextColumn get newCol => text().nullable()();
}
```

## 4. Regen

```bash
dart run build_runner build --delete-conflicting-outputs
```

Or `/regen`.

## 5. Local wipe

Tell the user to uninstall + reinstall (`/wipe-pixel`). PowerSync's
local schema is additive but won't reliably pick up the new column
without a fresh DB.

## 6. Verify

```bash
flutter analyze
```

If you reference the new column anywhere, the compiler catches it.

## Common gotchas

- Forgot to update `power_sync_schema.dart` → column is in Drift but
  PowerSync never replicates it → SQL error "no such column"
- Forgot to wipe local DB → existing devices read the old schema and
  the column is silently null
- Added the column but used it before pushing the migration → upload
  fails with "column does not exist"
