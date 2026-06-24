# Architecture — how it all fits at runtime

The runtime topology. Where [VISION.md](VISION.md) covers the *why*,
[PRIMITIVES.md](PRIMITIVES.md) the *atoms*, [FEATURES.md](FEATURES.md)
*what exists*, and [SCHEMA.md](SCHEMA.md) the *data layer*, this doc
covers **how the layers and data paths connect at runtime** — the
mental model you need before changing anything that crosses the
device/cloud boundary. **Authoritative for the runtime model.**

The five load-bearing invariants that make this model hold are in
[CLAUDE.md](../CLAUDE.md) ("Architecture invariants"); this doc is the
map, that section is the law.

**Inventory snapshot** (verified 2026-06-24): 58 feature folders · 192
routes · 58 DAOs · 38 synced tables · 66 migrations · 5 Edge Functions ·
2 per-user sync streams + 1 global.

---

## The layered stack

```
  Flutter UI (Material 3)        58 feature folders · 192 routes
        ↓
  Riverpod 3                     plain providers + notifiers, no codegen
        ↓
  go_router                      192 routes · auth-aware redirect
        ↓
  Drift over SQLite              58 DAOs · 38 tables · the UI's source of truth
        ⇅                        ← the sync boundary
  PowerSync                      bidirectional · CRUD upload queue + download streams
        ⇅
  Supabase (cloud)              Postgres + RLS · Storage · Auth · Realtime · 5 fns
```

**The load-bearing rule:** the local SQLite is the source of truth for
the UI. No widget, provider, or repository queries Supabase directly —
reads come from Drift streams, writes commit to Drift optimistically
(one frame), and PowerSync round-trips in the background. Everything
above Drift is offline-by-default and never shows an "offline" error;
everything below is gated on a single `space_id` column comparison,
which is what keeps RLS, sync rules, and conflict resolution cheap.

The only sanctioned exceptions to "never touch Supabase from UI" are
enumerated in [CLAUDE.md](../CLAUDE.md) under invariant #1 (auth, the
two PostgREST family fallbacks, the signed-URL/Storage helpers, and the
Realtime live-session layer).

---

## The four data paths

Same boundary, four mechanisms. *Which path a feature uses is the
architecture decision* — get it right and offline-first comes for free.

| # | Path | Mechanism | Offline-first? |
|---|---|---|---|
| 1 | Durable structured data | Drift ⇄ PowerSync ⇄ Postgres (`by_space`) | yes |
| 2 | Binary media | bytes → Supabase Storage; row carries a path string; views mint signed URLs | n/a (lazy, cached) |
| 3 | Family lens | `by_guardian` stream (1-level) + PostgREST fallback (2-level) | stream yes; REST no |
| 4 | Realtime / ephemeral | Supabase Realtime channels | never persisted |

1. **Durable structured data** — the local-first spine, ~99% of the
   app. Write → Drift → PowerSync CRUD queue → Postgres (RLS by
   `space_id`); reads return via the `by_space` stream.
2. **Binary media** — photos and PDFs *never* ride PowerSync (its budget
   is text + numbers). Bytes go straight to a private Storage bucket; the
   synced row carries only a path; views mint 1-hour signed URLs through
   the `sign-photo` Edge Function. The timed per-child *turn* shot is held
   local on the device until a teacher hearts it ([PHOTO_TURNS.md](PHOTO_TURNS.md)).
3. **Family lens** — guardians have a `members` row with a null
   `space_id`, so `by_space` delivers them nothing by design. A separate
   `by_guardian` stream (single-level subqueries, offline-first) feeds
   their own rows; per-subject reads needing a 2-level subquery fall back
   to direct PostgREST — the one place that is *not* offline-first.
4. **Realtime / ephemeral** — live-session coordination (which slide is
   up, a join code) over Supabase Realtime channels
   ([LIVE_SESSIONS.md](LIVE_SESSIONS.md)). Deliberately outside PowerSync,
   never persisted — the same exception auth gets.

**Outside the four paths.** Two *side-channels* cross the boundary but
bypass the sync layer like auth does: `auth` (Google OAuth → Supabase
Auth) and `voice` (Deepgram STT over WebSocket + ElevenLabs TTS, via the
`voice-token` / `tts-generate` brokers — *not* Supabase Realtime, an easy
mis-assumption). Five features are *local-only* (no synced table):
`kid_mode`, `dev_flags`, `calm`, `omnibox`, `settings`.

---

## Every feature mapped onto a path

Path 1 is the *substrate* under almost everything; paths 2–4 are
specializations layered on top. Counts below sum to all 58.

**Path 1 · durable (40 primary)** — `attendance` `subjects` `groups`
`guardians` `staff` `certifications` `pickup` `incidents` `supplies`
`vehicles` `schedule` `routines` `tasks` `entries` `reflections`
`insights` `recap` `review` `surveys` `missions` `curricula`
`activity_forge` `activity_runtime` `world` `child_world` `story`
`heroes` `spells` `spellbook` `action_words` `today` `daily` `cockpit`
`entities` `identity` `launch` `onboarding` `runtime` `tools` `toolkit`

**Path 2 · binary media (5 core + 12 more)** — core: `photos` `exports`
`captures` `poster` `speak`. Also move bytes: `entries` `subjects`
`heroes` `vehicles` `today` `daily` `recap` `story` `world` `action_words`
`activity_runtime` `curricula`.

**Path 3 · family lens (3 core)** — `family` `messages` `invites`, plus
family-side PostgREST reads of `subjects` / `today` / `recap` /
`schedule`, underpinned by the `guardians` entity.

**Path 4 · realtime (3 core + 11 castable)** — core: `live_session`
(the engine) `live_board` `games`. The engine is reused to cast a screen
by: `action_words` `activity_runtime` `child_world` `cockpit` `curricula`
`photos` `schedule` `subjects` `today` `world` `settings`.

**Outside (7)** — side-channels: `auth` `voice`. Local-only: `kid_mode`
`dev_flags` `calm` `omnibox` `settings`.

Three things this surfaces: local-first is overwhelmingly the default
(40 pure-durable, ~15 durable + a specialization, only `auth`/`voice`
truly outside); the realtime engine is leverage, not a feature (3 are
realtime, 14 can cast through one shared engine); and binary is bigger
than it looks (17 features move bytes, every one keeping PowerSync's
budget to path strings).

---

## Adding a synced table — the six places + deploy gates

Six edits, three server + three client, **all required**. Miss any one
and the table fails to sync *silently* — no error, empty local tables,
the app stuck on its loading spinner. (Long form: [CLAUDE.md](../CLAUDE.md)
"Adding a synced table touches six places" + the `new-table` /
`sync-add-table` skills + [EXTENDING.md](EXTENDING.md).)

```
  SERVER (Supabase)                     CLIENT (Flutter)
  1 migration SQL                       4 PowerSync schema
    table + space_id FK · RLS             Table('<name>', […])
    + replica identity full               + indexes if it grows
  2 publication                         5 Drift table class
    alter publication powersync           @DriftDatabase(tables:)
    add table public.<name>               mutators live in the DAO
  3 sync rules → by_space               6 DAO + codegen
    SELECT … WHERE space_id IN            watch · create · update_ · delete
    + redeploy on the dashboard          register · build_runner
                       ↓                        ↓
            Then — the deploy gates (after the six):
            supabase db push · PowerSync dashboard DEPLOY (#1 forgotten step)
            dart run build_runner build · wipe local storage on every device
```

Three traps the diagram encodes:
- The `sync_rules.yaml` in the repo is only source-of-truth — the
  **PowerSync dashboard is the runtime.** Forget to redeploy there and
  sync "succeeds" with zero rows. This is the most common silent break.
- **Indexes (step 4) only matter for tables that grow** (`entries`,
  `attendance_records`); without them every stream emission full-scans +
  sorts the whole table locally.
- **Join tables still need an explicit `id` PK** — a composite PK trips
  SQLite constraint 1811 and the upload retries forever.

---

## Tenancy enforcement — RLS, GRANTs, and the `app` schema

The mental model most people bring — "RLS gates per-user via
`auth.uid()`" — is **not** how this works, because `auth.uid()` returns
null in PostgREST requests on this ES256-keyed project (the gotcha is in
[CLAUDE.md](../CLAUDE.md)). Enforcement splits across two contexts:

- **Reads arrive via the sync streams**, which run as PowerSync's
  replication role and bypass PostgREST + RLS entirely. The stream
  *query* does the tenancy scoping (`space_id IN members`, or `user_id`
  for guardians) — and `auth.user_id()` *does* resolve in that context.
  That asymmetry (`auth.user_id()` works in streams; `auth.uid()` is null
  in PostgREST) is why reads work while per-user write-RLS doesn't.
- **Writes go through PostgREST**, where the **table GRANTs are the real
  gate**: `authenticated` gets insert/update/delete on every table, `anon`
  gets nothing. Write policies fall back to the DB role
  (`current_user = 'authenticated'`, ≈16 clauses). The ≈114
  `using(true)` / `with check(true)` clauses aren't lax — the GRANT layer
  is holding the line beneath them. Space-scoped read policies
  (`app.current_space_id()` / `program_id()`, ≈24) and director gates
  (`app.is_director()`, ≈3) are belt-and-suspenders for the PostgREST
  paths.
- **Helpers live in `app`, not `public`** (10 of them:
  `current_space_id`, `current_program_id`, `is_director`,
  `handle_new_user`, `accept_invite`, `scrub_other_subject_names`, and
  four `family_*` server-side read RPCs). PostgREST auto-exposes every
  `public` function at `/rest/v1/rpc/`; putting them in `app` keeps them
  callable from policies (granted to `authenticated`) while invisible to
  the REST API. Each is `SECURITY DEFINER` with `search_path = ''` and
  fully-qualified identifiers. Six take an explicit `caller_uid uuid`
  because `auth.uid()` is null *inside* definer functions too — the
  client passes `session.user.id`.

```
  authenticated request (ES256 JWT) — anon never granted writes
        ↓
  Gate 1 · table GRANTs ............ the real gate (authenticated CRUD; anon none)
        ↓
  Gate 2 · RLS policies ............ mostly using(true); writes by DB role;
                                     reads scoped by app.current_space_id()
        ↓
  row in public.* .................. every synced row carries space_id

  app-schema helpers (SECURITY DEFINER, hidden from PostgREST /rpc)
  sync streams ..................... different role — bypass PostgREST + RLS:
    by_space        space_id IN (SELECT space_id FROM members WHERE id = auth.user_id())
    by_guardian     user_id = auth.user_id()   (offline-first guardian rows)
    global_content  space_id IS NULL           (shared content bank, every program)
```

---

## The five Edge Functions

All vendor master keys are brokered server-side — never in `.env` or the
app bundle ([SECRETS.md](SECRETS.md)).

| Function | Purpose | Vendor |
|---|---|---|
| `voice-token` | mints a ≤30 s STT token for the WebSocket | Deepgram |
| `tts-generate` | text → speech for dictation/aura voices | ElevenLabs |
| `tts-subtitles` | text → speech **+ char-level word timings** for the `/speak` karaoke screen; cached globally in `tts-cache` | ElevenLabs |
| `sign-photo` | authorizes server-side, then signs private-bucket photo reads | — |
| `send-export` | mints a signed URL + emails an export's recipients, stamps `export_recipients` | Resend |

---

## See also

- [CLAUDE.md](../CLAUDE.md) — the architecture invariants (the law) + every known gotcha
- [SCHEMA.md](SCHEMA.md) — table-grained data layer · [FEATURES.md](FEATURES.md) — folder-grained feature registry
- [NAMING.md](NAMING.md) — the Space/Member/Group/Subject/Entry engine contract
- [VERTICALS.md](VERTICALS.md) — how the engine + experience re-skin to other domains
- [SECRETS.md](SECRETS.md) · [LIVE_SESSIONS.md](LIVE_SESSIONS.md) · [PHOTO_TURNS.md](PHOTO_TURNS.md) · [EXTENDING.md](EXTENDING.md)
