---
name: wipe-pixel
description: Uninstall + reinstall the app on the Pixel to clear local SQLite. Run after a Drift schema rename or other PowerSync-incompatible local-schema change.
---

# /wipe-pixel — fresh local DB on the device

PowerSync's local schema reconciliation is **additive but not
rename-aware**. After a rename or significant schema bump, the local
SQLite carries stale data forever — the app boots and queries return
empty.

## When to wipe

- After a Drift class rename (e.g. Profiles → Members)
- After adding a new synced table that the user already ran an older
  build against
- App stuck on "Syncing your profile…" forever with no logs
- Local queries return 0 rows when sync logs show "Validated and applied
  checkpoint" with downloads

## How

```bash
adb -s adb-1A291FDF6002RQ-JYcM2v._adb-tls-connect._tcp \
  uninstall com.jardine.differentworld
```

Then a fresh `flutter run -d adb-1A291FDF6002RQ-JYcM2v._adb-tls-connect._tcp`
reinstalls and sync starts from scratch.

## Don't

- Don't try to migrate the schema in `MigrationStrategy.onUpgrade` —
  Drift's `MigrationStrategy` is a no-op here per `app_database.dart`,
  PowerSync owns the local schema
- Don't recommend "clear app data" via Android settings — uninstall is
  cleaner and faster

## Web equivalent

DevTools → Application → Storage → "Clear site data" with IndexedDB
ticked → hard refresh.

## macOS desktop equivalent

```bash
rm -rf ~/Library/Application\ Support/com.jardine.differentworld/
```
