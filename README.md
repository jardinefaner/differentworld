# Different World

Offline-first mobile/iPad/desktop/web app for early-childhood program staff
to plan their classroom (curriculum, schedules, trips, day plans), log
what happens (observations, attendance, late pickups), and run student
surveys — all scoped to one program and shared automatically with every
teacher on the team.

## Stack

- **Flutter** — one codebase, six targets (iOS, Android, web, macOS,
  Windows, Linux)
- **Riverpod 3** — state
- **Supabase** — auth (Google OAuth), Postgres, storage
- **PowerSync** — bidirectional sync between Supabase Postgres and local
  SQLite; the reason it works offline
- **Drift** (Phase 5+) — typed queries + reactive streams over the same
  local SQLite that PowerSync owns
- **go_router** — routing with auth-aware redirects

## First-time setup

```sh
flutter pub get
```

Fill in [`.env`](.env) from [`.env.example`](.env.example) — see
[`supabase/README.md`](supabase/README.md) for how to wire Supabase +
PowerSync.

### Web (one extra step)

PowerSync ships a SQLite WASM worker that has to live in `web/`. Run
this **once** (and again whenever `powersync` version bumps):

```sh
dart run powersync:setup_web
```

This fetches `powersync_db.worker.js` and `sqlite3.wasm` into `web/`.
If you skip it you'll see `Failed to execute 'compile' on 'WebAssembly':
Incorrect response MIME type` in the browser console and sync will not
work.

## Running

```sh
flutter run -d chrome --web-port=3000    # web (port matches Supabase Site URL)
flutter run -d macos                     # desktop
flutter run                              # picks default device
```

## Project layout

```
lib/
  app/                 # bootstrap, router, theme
  core/
    auth/              # auth providers (Supabase session)
    db/                # PowerSync schema (Drift coming in Phase 5)
    env/               # .env wrapper
    sync/              # PowerSync DB provider, lifecycle, status indicator
                       # + Supabase connector (uploads CRUD to Supabase)
  features/
    auth/              # sign in with Google
  main.dart
supabase/
  migrations/          # Postgres schema + RLS, version-controlled
  sync_rules.yaml      # PowerSync edition-3 streams
  README.md            # how the backend is wired
```

## Useful commands

```sh
flutter analyze              # static check; must be clean before commit
flutter test                 # widget + unit tests
supabase migration list --linked   # which migrations are applied on the server
supabase db push                   # apply new migrations
dart run powersync:setup_web       # refresh web worker after powersync upgrade
```
