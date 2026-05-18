---
name: run-web
description: Launch on Chrome on port 3000 so the Supabase OAuth redirect to localhost:3000 works.
---

# /run-web — Chrome on port 3000

The Supabase project's redirect URL allow-list pins `localhost:3000`.
Running on any other port silently breaks OAuth sign-in.

```bash
flutter run -d chrome --web-port=3000
```

If Android Studio's run button launches with no `--web-port` flag, see
the `.idea/runConfigurations/main_dart.xml` change — it's preserved in
the repo so AS-launched runs pass `--web-port=3000`.

## If port 3000 is busy

```bash
lsof -nP -iTCP:3000 -sTCP:LISTEN
pgrep -fl "flutter_tools.snapshot.*run"
```

Kill stragglers. Multiple concurrent `flutter run` processes will fight
for the port; one silently falls back to a random port and OAuth breaks.

## After dependency / schema changes

```bash
dart run powersync:setup_web   # if powersync version bumped
flutter pub get
```

PowerSync needs `web/powersync_db.worker.js` + `web/sqlite3.wasm` which
are gitignored. The setup_web command regenerates them.

## Stale IndexedDB after Drift schema changes

If the app boots blank or stuck on "Syncing your profile…" on web,
clear IndexedDB:

DevTools → Application → Storage → "Clear site data" with IndexedDB
ticked → hard refresh.
