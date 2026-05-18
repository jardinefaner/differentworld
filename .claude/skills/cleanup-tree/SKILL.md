---
name: cleanup-tree
description: Decision tree for when to flutter clean / build_runner / setup_web / wipe local DB / supabase push. Triggered when behavior gets weird and you're not sure which reset to run.
---

# /cleanup-tree — which reset to run

## `flutter clean && flutter pub get`

When:
- Pubspec dependency was added/removed/upgraded
- `git pull` brought in pubspec changes
- Mysterious build errors that don't match the source (cache rot)
- After build_runner crashes or partial regens
- Switching branches with different Flutter / Dart versions
- New native plugin (`share_plus`, `image_picker`, `app_links`, etc.)

→ `/clean`

## `dart run build_runner build`

When:
- Drift table classes changed in `lib/core/db/app_database.dart`
- Freezed / json_serializable classes changed
- Any `.dart` file with codegen annotations was edited

If it says "wrote 0 outputs" but you know source changed:
`dart run build_runner clean && dart run build_runner build`

→ `/regen`

## `dart run powersync:setup_web`

When:
- First time setting up the project locally
- `powersync` package version bumped
- `web/sqlite3.wasm` or `web/powersync_db.worker.js` missing
- Browser console: `Failed to execute 'compile' on 'WebAssembly':
  Incorrect response MIME type`

## Clear local device storage

When:
- A migration renamed a table or column that PowerSync syncs
- PowerSync `appSchema` declaration in Dart changed
- App boots stuck on "Syncing your profile…" forever
- Logs show "Validated and applied checkpoint" but UI shows empty data
- Silent schema mismatch between local SQLite and server

How:
- **Pixel**: `adb uninstall com.jardine.differentworld` + fresh
  `flutter run` (or use `/wipe-pixel`)
- **Web (Chrome)**: DevTools → Application → Storage → "Clear site data"
  with IndexedDB ticked → hard refresh
- **macOS**: `rm -rf ~/Library/Application\ Support/com.jardine.differentworld/`

→ `/wipe-pixel`

## `supabase db push`

When:
- A new migration was written
- Pre-authorized; run directly (Bash permission granted)

→ `/push-db`

## The full sequence after a Drift rename

See `sync-add-table` — 12 steps in strict order. Don't shortcut.
