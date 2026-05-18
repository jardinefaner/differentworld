---
name: gotchas
description: Reminder of the known gotchas that bit us before. Triggered when symptoms match a documented gotcha.
---

# Known gotchas (the short list)

Full text in CLAUDE.md's "Known gotchas" section. Quick reference:

## Drift ↔ PowerSync ambiguous `Column` import

Both packages export `Column`. Scope the powersync import:

```dart
import 'package:powersync/powersync.dart' show PowerSyncDatabase;
```

Otherwise drift_dev silently fails to generate code.

## No `riverpod_generator`

Dropped because of analyzer version conflict. Use plain `Provider`,
`StreamProvider`, `FutureProvider`, `Notifier`.

## Drift schema is read-only

`MigrationStrategy` is a no-op for both `onCreate` and `onUpgrade` —
PowerSync owns the schema. Don't try to migrate from Drift's side.

## `.value` not `.valueOrNull`

Riverpod 3 renamed `AsyncValue.valueOrNull` → `AsyncValue.value`
(still nullable). `requireValue` throws on loading/error.

## Web wasm after powersync version bump

```bash
dart run powersync:setup_web
```

## Stale IndexedDB after Drift schema changes

DevTools → Application → Storage → "Clear site data" with IndexedDB
ticked → hard refresh.

## `auth.uid()` returns null in REST requests

ES256 JWT signing project. PostgREST authenticates the JWT but doesn't
populate `request.jwt.claims`. RLS policies that gate on `auth.uid() is
not null` reject every authenticated write with `42501`.

Workaround: relaxed policies (`to authenticated using (true) with check (true)`)
and rely on the GRANT layer (only `authenticated` has write privs).

Symptom: `new row violates row-level security policy` on PowerSync
CRUD uploads.

## PowerSync `uploadData` must guard null session

Otherwise it falls back to the anon key and every write fails RLS.
Already handled in `supabase_connector.dart`.

## `42501 permission denied for table X`

GRANT-level missing on the `authenticated` role. Different from "new
row violates row-level security policy" (that one's RLS).

## Stuck on "Syncing your profile…"

Local SQLite has the old schema after a rename. **Uninstall + reinstall**
on the device (`/wipe-pixel`). Web: clear IndexedDB.

## "Validated and applied checkpoint" with 0 rows

PowerSync dashboard has stale sync rules. The repo's `sync_rules.yaml`
is source of truth; the dashboard is runtime. **Redeploy.**

## Mobile OAuth redirect

Custom scheme `com.jardine.differentworld://login-callback` must be in
Supabase's Redirect URLs allowlist (exact match, no wildcards).

## Web dev port collisions

Port 3000 only. `.idea/runConfigurations/main_dart.xml` enforces it for
AS launches. From terminal: `flutter run -d chrome --web-port=3000`.
