---
name: no-direct-supabase
description: Don't call Supabase.instance.client from UI / providers / repositories. Reads via Drift streams, writes via Drift mutators. Three documented exceptions.
---

# No direct Supabase calls from app code

Same rule as `local-first-reads` but stricter — even writes shouldn't
touch `Supabase.instance.client.from(...)`. Drift writes, PowerSync
uploads.

## Forbidden

```dart
// Reads
await Supabase.instance.client.from('groups').select();

// Writes
await Supabase.instance.client.from('groups').insert(...);
await Supabase.instance.client.from('groups').update(...).eq(...);
await Supabase.instance.client.from('groups').delete().eq(...);

// Storage downloads/uploads through the data-row path
```

## The three legit exceptions

1. **Auth** — `Supabase.instance.client.auth.signInWithOAuth(...)` etc.
   PowerSync doesn't manage auth.

2. **The PowerSync upload connector** — `lib/core/sync/supabase_connector.dart`.
   The upload callback IS the bridge; Supabase HAS to be called here.

3. **Server-side atomic RPC** — `Supabase.instance.client.rpc(...)`
   when the operation must be one server-side transaction (e.g.
   `accept_invite`). Document at the call site, justify in the commit.

## Plus one for media

`Supabase.instance.client.storage.from('person-photos').uploadBinary(...)`
in `PhotoService` is correct — see `photo-via-storage`. Binary uploads
intentionally bypass PowerSync.

## If you find yourself reaching for it

Stop. Add a Drift method to `AppDatabase` and an Actions method that
calls it. The 5 minutes of boilerplate are the difference between
"works offline" and "fails silently."

## Why not just gate at runtime?

You could add a lint rule. We haven't, because the manual discipline +
agent guards have worked so far. If we start seeing direct-Supabase
sneak in via PRs, that's the time to add a custom analyzer rule.
