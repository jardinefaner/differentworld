# Extending the systems — the points where the app grows, and the footguns

Future-proofing index: for each extension point built recently, the ONE place
to add, the sites that must stay in sync, the test/guard that protects it, and
the footgun that bites if you skip a step. Keep this current — when you add a
new extension point, add its row here.

---

## Add a Live Board instrument (docs/LIVE_BOARD.md)

The teacher-instrument rack. An instrument = a wire-state shape + an auto-fit
stage + a phone control.

**Touch, in order:**
1. `lib/features/live_board/board_game.dart`
   - add the value to `enum BoardInstrument`
   - add its `'kind'` string case in `BoardState.fromMap` ← **the silent-gap
     spot** (the switches below are compiler-checked; this string map is not)
   - add a case in `buildStage` (exhaustive switch → compiler reminds you)
   - write the `_…Stage` widget — **MUST auto-fit** (`FittedBox`), never scroll
2. `lib/features/live_board/live_board_screen.dart`
   - state fields (a controller/focus/int as the instrument needs) + dispose them
   - a case in the `_state` getter, the controls `switch`, and `_focusActive`
     (all exhaustive — the compiler flags a miss)
   - one entry in the chip-rack list
3. reuse `_RevealControls` (parameterized: label/hint/nextLabel/minLines) for a
   type-text-then-step instrument; reuse `_RosterPicker` for a pick-a-kid one.

**Protected by:** `test/widget/board_game_test.dart` loops EVERY enum value and
asserts (a) it round-trips through the wire (catches a missing `fromMap` case)
and (b) its stage renders without throwing. Add a content-specific assertion
too, but the loops catch the silent gaps.

**Footgun:** a new enum value without a `fromMap` case decodes to `idle` — a
dead chip that does nothing on the room screen, with no error. The round-trip
test is the guard; don't remove it.

**No realtime code needed:** `BoardGame` is a cast-only `GameDefinition`
registered in `game_registry.dart`; the existing cast receiver renders any
instrument. Drive via `castStage(BoardGame.gameId, state.toMap())`.

---

## Add a role's tool (role-as-home; docs/VISION.md)

**Touch:** `lib/features/today/role_tools.dart` only.
- add a `RoleTool` const (label · icon · route · `allowed` capability gate)
- add it to the role's ordered list in `toolsForRole(roleKey)`

**Protected by:** `test/unit/role_tools_test.dart` (per-role lead + absolute
routes). The `YourToolsStrip` applies the capability filter; nothing else to
wire — it's a pure data table by design.

**Footgun:** set the `allowed` gate, or the palette offers a tool the person
can't use (a dead tap). Use the existing `_canObserve` / `_canManageSpace` /
`_always` predicates; add a new one rather than inlining a cap check.

---

## Add an Entry kind (the unified `entries` table)

**Touch:** `lib/features/entries/entries_providers.dart`
- add the `static const String` to `EntryKind`
- add a `create…` method on `EntryActions` (mirror an existing one)
- read it where it's consumed (the Book, a feed, the character sheet)

**No migration** — `entries.details`/`kind` are text columns; a new kind value
just works on the synced table.

**Footgun (PHOTOS — silent data loss offline):** if the kind carries a photo,
the attachment id MUST be pre-generated and passed to BOTH
`PhotoService.uploadOnly(entityKind:'attachment', entityId: <id>)` AND the
`attachments.add(id: <id>, …)` / `create…(photoIds: [<id>])` call. Mismatch →
a deferred offline upload patches a non-existent row and the photo is lost
ONLY offline (online returns the real path immediately, so it hides in dev).
Reference: `createWorkSample`, `createObservation`, `snapWork`. See the
CLAUDE.md "Offline attachment uploads" gotcha.

---

## Add a synced table · a top-level screen · a color

These have their own canonical guides — don't reinvent:
- **Synced table** — the 6-place checklist (CLAUDE.md §3) + the `new-table` /
  `sync-add-table` skills. Miss one and it silently won't sync.
- **Top-level screen** — wire all 4 discovery surfaces (router / omnibox /
  drawer / settings; CLAUDE.md §3a), claim them in `docs/FEATURES.md`
  (feature-mapper verifies), and pass the Screen Rubric + Clarity rubric.
- **Color** — read from the `ColorScheme` / `AppColors`; for a content-accent
  fill use `AppColors.onAccent`. The theme-adherence check + guard enforce it
  (docs/THEME_ADHERENCE.md).

---

## Cross-cutting laws any new surface inherits

- **Auto-fit** on any present/stage surface — `FittedBox`, never scroll/clip.
- **Offline-first** — local reads/writes through Drift; never `await` a network
  round-trip in a handler; never show an "offline" error.
- **Calm + clear** — lead with one action; collapse secondary sections
  (`CollapsibleSection`); score against docs/CLARITY_RUBRIC.md.
- **Kid surfaces lock** — kid-mode strips chrome; a staff-only exit gesture.

---

## Future-proofing backlog (sequenced, not yet done)

- ~~Action-layer test harness~~ **DONE** — `test/unit/entry_actions_db_test.dart`
  opens `AppDatabase.forTesting(NativeDatabase.memory())` + `createMigrator()
  .createAll()`, seeds a space/member, overrides `appDatabaseProvider` +
  `viewerProvider`, and runs `EntryActions` end-to-end (the offline-photo
  footgun is now an executable test). Copy its `setUp` to test any other
  action/DAO method.
- **Live Board instrument registry** — fold the per-instrument sites into one
  declaration (id + stage + controls + state) so adding one is a single entry,
  not edits across board_game + the screen. (Deferred: the per-instrument
  control STATE makes it a real refactor; the completeness test guards the
  current shape meanwhile.)
- **Role-as-home Roles 2–4**:
  - **Role-2 (role shapes the home lead)** — *substantially already done*, not
    via a reorder but via self-hiding conditional cards in `today_sections.dart`:
    `_ReadyToRunCard`/`_DirectorPulseCard` (director), `_RightNowCard`/
    `_ChecklistCallToAction`/`_ActionWordsCard` (daily-logger), `_IdentityStrip`/
    `_CoveringTodayCard` (specialist/substitute), `LeadingTodayCard` (block
    leads), `YourToolsStrip` (Role-1 per-role tools). The one *genuine* remaining
    gap is lead PRIORITY — a director's first card is `_ReadyToRunCard`/
    `_RightNowCard`, not their `_DirectorPulseCard` (buried at ~pos 13). Closing
    it is a per-role lead-order pick, NOT a screen rebuild; deferred as an opt-in
    refinement because the screen is calm (CLARITY work) and reordering risks it.
  - **Role-3 (archetype tunes the experience)** — FIRST LIGHT done: the
    self-authored archetype (`archetypes.dart` + `viewer.archetypeId`, set on the
    member-detail `ArchetypeCard`) now shows up beside the role line in the
    drawer. STILL TO DO: let the archetype gently re-order/emphasize the
    `YourToolsStrip` palette (decorates, never gates — e.g. a Connector floats
    Messages up, a Protector floats Incidents up). The data hook
    (`viewer.archetypeId`) is in place; `role_tools.dart` is where the tuning
    would read it.
  - **Role-4 (kid verb-job reshapes kid-mode)** — unstarted.
- **Snap-paper Wave 3** — the starred keepers embedded in the Summer Book PDF
  (needs network-image bytes in an offline-first PDF).
- **Dependency bumps** — `app_links` 7, `powersync` 2.3, `supabase_flutter`
  2.14, `record` 7 — each its own branch + on-device retest (deep-link / sync /
  voice surfaces).
- **i18n** — `flutter gen-l10n` + extract strings (the Lauren/Spanish dream).
