---
name: architecture
description: Reminder of the 5 load-bearing architecture invariants. Triggered when proposing changes that might violate them.
---

# Architecture invariants

These five rules are load-bearing — break them and offline guarantees,
performance, or correctness suffer.

## 1. Local-first reads, local-first writes

The local SQLite is the source of truth for the UI. Never query
Supabase directly from a widget / provider / repository.

See: `local-first-reads`, `optimistic-writes`.

Exceptions (documented): auth (`supabase.auth.*`), PowerSync's upload
connector, `supabase.rpc('accept_invite', ...)`.

## 2. Every synced table carries `space_id`

RLS and PowerSync stream queries gate on a single-column comparison.

See: `space-id-everywhere`.

## 3. Adding a synced table touches 5 places

Migration → publication → sync rules → PowerSync schema → Drift class.
Miss any and it silently doesn't sync.

See: `new-table`, `sync-add-table` (longer reference).

## 4. IDs are uuid server, text client, generated in Dart

Offline writes need stable PKs.

See: `uuid-clientside`.

## 5. Type mapping: Postgres → local SQLite

| Postgres | Local schema | Notes |
|---|---|---|
| uuid PK | implicit `id` TEXT | PowerSync adds it; don't declare |
| text | `Column.text` | |
| boolean | `Column.integer` | 0/1 |
| date / timestamptz | `Column.text` | ISO 8601 string |
| jsonb | `Column.text` | raw JSON; parse client-side |
| int / float | `Column.integer` / `Column.real` | |

## Where to look

- Schema source of truth: `supabase/migrations/`
- Sync rules: `supabase/sync_rules.yaml`
- Schema mirror: `lib/core/db/power_sync_schema.dart`
- Drift tables: `lib/core/db/app_database.dart`
- Auth: `lib/core/auth/auth_providers.dart`
- Sync wiring: `lib/core/sync/`
- Features: `lib/features/`

CLAUDE.md is the source of truth for any deeper question.
