# Platform Readiness Rubric

**How every feature fares on web + desktop, not just mobile.** This app is
phone-first; mobile gets the attention and web/desktop drift. This is the
scorecard that makes the drift visible and prioritizes the catch-up.

**Status:** first pass 2026-06-01 (33 folders). **Second pass 2026-09-03** —
the app had grown to 67 folders, so HALF of it had never been scored, and the
rubric had sat still for three months while claiming to be living. All 34
missing features are scored below.

**The second pass was scripted, not read.** `tool/score_platform.py` scores
every folder on all five axes from source, so this can be re-run in a minute
instead of re-read in an afternoon — which is the actual reason the first pass
went stale. The script produces EVIDENCE, not verdicts: it names the files that
call a camera plugin, the screens with no width-awareness, the folders with no
error path. Every ⚠️ below was then checked by hand, and roughly a third of the
script's first-cut flags were false positives worth understanding (a camera
call already behind `isMobileCapturePlatform` is the CORRECT shape; a static
screen with no async data has no four states to design). The script now knows
both of those.

    python3 tool/score_platform.py --unscored   # anything missing from this doc
    python3 tool/score_platform.py picker       # one feature, with evidence

Living document — re-score a row when you touch its screens; add the date.

**Catch-up landed 2026-06-01 (P0→P3):** both web crashes fixed (photos,
entries); camera/QR-scan gated to mobile with graceful desktop fallbacks
(photos, vehicles); subjects timeline capped on desktop; the **schedule
cohorts×time matrix** shipped (wide screens show every cohort as a column);
presenter keyboard controls on all four reveal/advance host games
(This-or-That, Fact-or-Fib, Riddles, Story-Starters) via the shared
`PresenterShortcuts`. The rows + gap list below reflect this.

**What remains is optional richness, not breakage.** Every remaining ⚠️ is
an *already width-capped* single-column screen (readable on desktop, just
not multi-column). The richer layouts are polish — and several aren't
cleanly tractable: messages has no index screen to pair in a master-detail,
settings is route-based (master-detail = inline-routing, a big change), and
supplies/survey are row/table content that `ResponsiveGrid` (forced-aspect
cards) would distort. Do these WITH eyes on the running web build, not blind.

---

## How to read it

Each feature is scored on five columns. Legend:

- ✅ **solid** — works + feels intentional on this axis.
- ⚠️ **partial** — works but suboptimal (e.g. a phone column that stretches
  on desktop; a touch-only gesture with only a tap fallback).
- ❌ **broken/missing** — crashes or is unusable on the target.
- — **N/A** — no standalone screen, or the axis doesn't apply.

| Column | What ✅ means |
|---|---|
| **Web** | Runs on a Flutter web build without a runtime crash on a path the screen reaches. ❌ = ungated `dart:io` / native-only plugin invoked on web. |
| **Desktop** | Runs on macOS/Windows/Linux. ❌ = native-only capture (camera/mic/QR) with no desktop implementation **and** no fallback. |
| **Adaptive** | Uses wide-screen space: a real multi-column / master-detail layout where it helps, OR a form/detail correctly centered with a max-width, OR a full-bleed surface that's meant to fill. ⚠️ = a phone single-column that just stretches and leaves the desktop half-empty. |
| **Pointer/KB** | Mouse hover/cursor, focus order, and keyboard shortcuts where they'd help (esp. a presenter on a laptop). ⚠️ = touch-only affordance (swipe/long-press) with only a tap fallback, no hover/right-click/keys. |
| **States** | The four screen states designed — loading / empty / error / data (per [docs/SCREEN_RUBRIC.md](SCREEN_RUBRIC.md)). |

**Important platform fact (de-mythed during this audit):** on Flutter web,
`import 'dart:io'` and native plugins **compile** (the toolchain stubs them /
the federated plugin resolves) — they fail at **runtime** only when an API is
actually invoked on web. So the only true web breakers are code paths that
call `dart:io`/native APIs **without a `kIsWeb` guard**. Most camera/mic sites
already degrade via `kIsWeb` gates or `try/catch`; only two paths don't.

---

## Scorecard

### Daily core

| Feature | Web | Desktop | Adaptive | Pointer/KB | States | Biggest web/desktop gap |
|---|:--:|:--:|:--:|:--:|:--:|---|
| today | ✅ | ✅ | ✅ | ✅ | ✅ | Solid — `ResponsivePage` + ≥1100 dp 2-col group cards. |
| insights | ✅ | ✅ | ✅ | ✅ | ✅ | Best-in-class — explicit 3-column severity dashboard on wide. |
| captures | ✅ | ✅ | ✅ | ⚠️ | ✅ | `ResponsiveGrid` (2–3 col) good; multi-select is long-press only (no right-click/checkbox). |
| schedule | ✅ | ✅ | ✅ | ⚠️ | ✅ | **Matrix shipped 2026-06-01:** wide screens show every cohort as a side-by-side column (reusing `_CohortDay`); phones keep tabs. (reorder/edit still tap-only; per-column "+" is v2.) |
| attendance | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | Single full-width roster at all widths (no master-detail); Present/Absent swipe-only (has inline-button fallback). |
| tasks | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | Width-capped but stays single column on desktop; snooze/dismiss swipe-only (action-sheet fallback). |
| review | ✅ | ✅ | ⚠️ | ✅ | ⚠️ | Phone `PageView` is a narrow card in a wide void on desktop; **no error state** (load error → "all clear"). |
| entries | ✅ | ✅ | ✅ | ✅ | ✅ | **Fixed 2026-06-01:** Cmd/Ctrl+V image-paste uses `XFile.fromData` (in-memory) instead of a temp-file write — no more web crash. |

### Roster & family

| Feature | Web | Desktop | Adaptive | Pointer/KB | States | Biggest web/desktop gap |
|---|:--:|:--:|:--:|:--:|:--:|---|
| groups | ✅ | ✅ | ✅ | ✅ | ✅ | Roster reflows 1→3 col via `ResponsiveGrid`; all states designed. |
| family | ✅ | ✅ | ✅ | ✅ | ✅ | `ResponsivePage` + `LayoutBuilder`; PDFs via signed URL + `url_launcher` (web-safe). |
| exports | ✅ | ✅ | ✅ | ✅ | ✅ | `printing` ships a web impl — `sharePdf` = browser download on web. |
| subjects | ✅ | ✅ | ✅ | ✅ | ✅ | **Fixed 2026-06-01:** the per-child timeline is capped + centered (1200) on desktop instead of running edge-to-edge. |
| messages | ✅ | ✅ | ⚠️ | ✅ | ✅ | Thread single column (bubbles cap 560); index + chrome stretch, no master-detail. Attach-photo is a stub (no crash). |
| guardians | — | — | — | ✅ | — | No standalone screen — embedded in subject detail; inherits host. |
| certifications | — | — | — | ✅ | ✅ | No standalone screen — `MemberCertificationsSection` in member detail; inherits host. |
| pickup | — | — | — | ✅ | — | No standalone screen — embedded in subject detail; inherits host. |

### Engagement (activities, surveys, live)

| Feature | Web | Desktop | Adaptive | Pointer/KB | States | Biggest web/desktop gap |
|---|:--:|:--:|:--:|:--:|:--:|---|
| toolkit | ✅ | ✅ | ✅ | ✅ | ✅ | Gold standard — `FormFactor` + `MasterDetailScaffold` true two-pane. |
| missions | ✅ | ✅ | ✅ | ✅ | ✅ | Pure Drift, `ResponsivePage`, all states; centered edit sheet. |
| live_session | ✅ | ✅ | ✅ | ⚠️ | ✅ | Realtime + full-bleed present/control — but a laptop presenter has **zero keyboard shortcuts** (arrow = next/back, R = reveal). |
| surveys | ✅ | ✅ | ⚠️ | ✅ | ✅ | `dart:io` CSV + TTS correctly `kIsWeb`-gated; `survey_table_screen` is a single-column ListView that wastes a wide data-grid. |
| activity_runtime | ⚠️ | ⚠️ | ✅ | ✅ | ✅ | **Keyboard added 2026-06-01** to the reveal/advance host games (This-or-That, Fact-or-Fib, Riddles, Story-Starters). Remaining: camera games still degrade to "No camera here" off-mobile (no upload fallback); tally games are tap-only (by design). |
| curricula | ✅ | ✅ | ⚠️ | ✅ | — | Static reference — single-column ListView stretches on desktop (no two-pane session list/detail). |
| kid_mode | ✅ | ✅ | — | ✅ | — | N/A surface — `Notifier` + centered PIN dialog. |
| runtime | ✅ | ✅ | — | — | — | Pure rule-engine logic, no UI — fully portable. |

### System & ops

| Feature | Web | Desktop | Adaptive | Pointer/KB | States | Biggest web/desktop gap |
|---|:--:|:--:|:--:|:--:|:--:|---|
| omnibox | ✅ | ✅ | ✅ | ✅ | ✅ | THE command surface — real Cmd/Ctrl+K, overlay centers at 640. Gap: overlay mic is a "coming soon" stub. |
| onboarding | ✅ | ✅ | ✅ | ✅ | ✅ | Forms centered (`ConstrainedBox` 480); offstage-TextField PIN supports paste/IME. Nit: PIN cells 44 dp (<48). |
| invites | ✅ | ⚠️ | ✅ | ✅ | ✅ | Share/QR-gen web-safe (`qr_flutter`, `share_plus` web fallback); the QR **scanner** is native camera (no desktop) — but redemption is code-entry, so it degrades. |
| supplies | ✅ | ✅ | ⚠️ | ✅ | ✅ | Capped single-column (`ResponsivePage`, acceptable). Items are `ListTile` rows, so `ResponsiveGrid` would distort — a 2-col-of-rows layout is optional polish. |
| settings | ✅ | ✅ | ⚠️ | ✅ | ✅ | Responsive form primitives, correct as a centered column — but stays single-column even >1200; a settings index/detail master-detail would use the space. |
| auth | ✅ | ✅ | ✅ | ✅ | ⚠️ | OAuth `redirectTo` from `Uri.base` — every web origin must be on Supabase's Redirect-URL allowlist or sign-in dead-ends on a blank page; no state taxonomy (just spinner+inline error). |
| vehicles | ✅ | ✅ | ✅ | ✅ | ✅ | **Fixed 2026-06-01:** scan action mobile-only; scan screen shows a "scan on your phone" fallback off-mobile instead of mounting `mobile_scanner`. List/detail use `ResponsiveGrid`. |
| photos | ✅ | ✅ | ✅ | ✅ | ⚠️ | **Fixed 2026-06-01:** web compresses on-thread + surfaces failed uploads (no `dart:io` queue crash); camera gated to mobile, web/desktop file-pick. Display web-safe. |
| voice | ⚠️ | ❌ | — | — | ⚠️ | Mic dictation `kIsWeb`-gated (web needs HTTPS+getUserMedia); no desktop mic story (`record` unverified on macOS/Win/Linux). Service layer, no UI. |

---

### Curriculum, worlds & play — *scored 2026-09-03*

| Feature | Web | Desktop | Adaptive | Pointer/KB | States | Biggest web/desktop gap |
|---|:--:|:--:|:--:|:--:|:--:|---|
| action_words | ✅ | ✅ | ✅ | ✅ | ✅ | **Fixed 2026-09-03:** the two slideshow-shaped present surfaces (`beat_presenter`, `world_present_screen`) now take → / Enter / ← via `PresenterShortcuts`. A deck shown on the TV is usually driven from a laptop, where the keyboard is the remote — not reaching across to tap the screen the room is watching. |
| world | ✅ | ✅ | ✅ | ✅ | ✅ | Solid. |
| child_world | ✅ | ✅ | ✅ | ✅ | ⚠️ | **Real defect:** `groupsProvider` read as `.value ?? const <Group>[]` (line 70) — a FAILED load renders as an EMPTY world with no error. The documented gotcha, and NOT covered by `swallowed_error_test.dart`. |
| games | ✅ | ✅ | ✅ | ✅ | ✅ | Stages are raw canvases by design; host controls keyboard-driven. |
| game_content | ✅ | ✅ | ✅ | ✅ | ✅ | **Fixed 2026-09-03:** the picture library offered "Take a photo" ungated — a dead button on web/desktop. Now `isMobileCapturePlatform`, gallery still everywhere. |
| heroes | ✅ | ✅ | ✅ | ✅ | ✅ | Camera correctly gated with a gallery fallback. |
| spells | ✅ | ✅ | ✅ | ✅ | — | Static content; no async to state. |
| spellbook | ✅ | ✅ | ✅ | ✅ | ⚠️ | Watches four providers with no loading or error path; low blast radius (a small daily card). |
| story | ✅ | ✅ | ✅ | ✅ | ✅ | Solid. |
| activity_forge | ✅ | ✅ | ✅ | ✅ | ⚠️ | No loading or error state on the lens/forge reads. |

### Live, present & pick — *scored 2026-09-03*

| Feature | Web | Desktop | Adaptive | Pointer/KB | States | Biggest web/desktop gap |
|---|:--:|:--:|:--:|:--:|:--:|---|
| live_board | ✅ | ✅ | ✅ | ✅ | ✅ | **Fixed 2026-09-03:** it subscribed to `peers` but not `status`, so a wedged Realtime printed the join instructions anyway — walking a teacher to the TV to type a code that could never connect. The three zero-peer states (connecting / live-and-empty / dead) are now three different sentences, pinned by `live_status_copy_test.dart`. The app-wide cast pill also grew an error face, which is Realtime's ONLY on-device health surface. |
| speak | ✅ | ✅ | ✅ | ⚠️ | — | A presentation surface driven by touch; a laptop presenter has no keys. Raw canvas by design, so no four states. |
| picker | ✅ | ✅ | ✅ | ✅ | ✅ | Solid. |
| rotation | ✅ | ✅ | ✅ | ✅ | ⚠️ | No error state on the rotation reads. |

### Day shape & ops — *scored 2026-09-03*

| Feature | Web | Desktop | Adaptive | Pointer/KB | States | Biggest web/desktop gap |
|---|:--:|:--:|:--:|:--:|:--:|---|
| cockpit | ✅ | ✅ | ✅ | ✅ | ✅ | The default home. Solid on all axes. |
| launch | ✅ | ✅ | ✅ | ✅ | ⚠️ | `/ready` watches six providers with no loading or error path. |
| readiness | ✅ | ✅ | — | — | — | Providers only; no standalone screen. |
| daily | ✅ | ✅ | ✅ | ✅ | ⚠️ | Camera correctly gated. No error state on the response reads. |
| recap | ✅ | ✅ | ⚠️ | ✅ | ✅ | Single column at every width — a composer that would benefit from a wide two-pane. |
| reflections | ✅ | ✅ | ⚠️ | ✅ | ✅ | Same: single column, no width-awareness. |
| routines | ✅ | ✅ | ⚠️ | ✅ | ✅ | Same. |
| rooms | ✅ | ✅ | ✅ | ✅ | ✅ | Solid. |
| rollover | ✅ | ✅ | ✅ | ✅ | ✅ | Solid. |
| class_memory | ✅ | ✅ | ✅ | ✅ | ✅ | Solid (its error state was fixed in an earlier wave). |
| incidents | ✅ | ✅ | ✅ | ✅ | ✅ | Solid. |
| staff | ✅ | ✅ | ✅ | ✅ | ✅ | Solid. |
| roles | ✅ | ✅ | ✅ | ✅ | ⚠️ | Role preview: no loading or error path. |

### Tools, meta & dev — *scored 2026-09-03*

| Feature | Web | Desktop | Adaptive | Pointer/KB | States | Biggest web/desktop gap |
|---|:--:|:--:|:--:|:--:|:--:|---|
| tools | ✅ | ✅ | ✅ | ✅ | — | Static index; nothing async. |
| calm | ✅ | ✅ | ✅ | ✅ | — | Static breathing surface. |
| poster | ✅ | ✅ | ✅ | ✅ | — | **Fixed 2026-09-03:** offered "Take a photo" ungated. Print path is web-safe (`printing` ships a web impl). |
| entities | ✅ | ✅ | ⚠️ | ✅ | ⚠️ | 1k lines, single column, no error path on the entity reads. |
| identity | ✅ | ✅ | — | — | — | Providers only. |
| sandbox | ✅ | ✅ | ⚠️ | ✅ | ⚠️ | **Web fixed 2026-09-03** — it imported `drift/native.dart`, and routing it pulled `dart:ffi` into the web build and broke it entirely. Now a conditional import (`WasmDatabase` on web). Picker is single-column; no empty state (it always has content). |
| dev_flags | ⚠️ | ✅ | — | — | — | `File` + `getApplicationDocumentsDirectory` with no `kIsWeb` guard, so the flag button throws on a web DEBUG build. Debug-only and never in a release bundle — lowest-priority row in this doc, listed for completeness. |

---

## Prioritized gaps — status (catch-up landed 2026-06-01)

### P0 — Web runtime crashes — ✅ DONE
1. ~~**photos** `photo_upload_queue.dart` ungated `dart:io`~~ — **fixed:** web compresses on the main thread (no `Isolate.run`) and surfaces a failed upload instead of hitting the native disk queue; `enqueue` carries a defensive `kIsWeb` guard.
2. ~~**entries** Cmd/Ctrl+V image-paste~~ — **fixed:** swapped to `XFile.fromData` (in-memory, web + native), dropping the temp-file write and three now-unused imports.

### P1 — Native capture, no desktop story — ✅ DONE
3. ~~**vehicles `/vehicles/scan`** + **invites QR**~~ — **fixed:** scan action is mobile-only (`isMobileCapturePlatform`); the scan screen shows a "scan on your phone" fallback off-mobile instead of mounting `mobile_scanner`. Invite redemption was already code-entry.
4. ~~**photos / activity camera**~~ — **fixed:** the camera affordance is gated to mobile; web + desktop get the file-picker. (Activity camera games already degrade via try/catch.)
5. **voice** mic — DEFERRED (lowest-impact; dictation is an enhancement): still no desktop mic story, web needs HTTPS + getUserMedia.

### P2 — Adaptive layout
- **subjects** — ✅ DONE: capped + centered on desktop.
- **schedule** — ✅ DONE: the cohorts-side-by-side **matrix** ships on wide screens. (v1 = columns of the per-cohort day, reusing `_CohortDay`; per-column "+" and a time-aligned grid are v2.)
- **Remaining — optional richness, NOT breakage** (every one is already width-capped, readable on desktop, just single-column): **surveys table** (→ a wide `DataTable`), **attendance** (→ master-detail roster), **supplies** (row-tiles → a 2-col-of-rows layout, not a card grid), **tasks / review / curricula** (→ second pane / cap). Two need bigger reworks and aren't cleanly tractable: **messages** has no index screen to pair in a master-detail, and **settings** is route-based (master-detail = inline routing). Do these with eyes on the running web build.

### P3 — Pointer & keyboard
- **host reveal/advance games** — ✅ DONE: This-or-That, Fact-or-Fib, Riddles, Story-Starters take arrow / Space / R via `PresenterShortcuts`.
- **Remaining:** the **live** present/control screens (charades / board / live This-or-That) — phone-driven today, so keyboard is a smaller win; the **tally** games (rhyme-time, letter-words) were skipped on purpose (rapid tapping, not a keyboard fit). attendance/tasks swipe + captures long-press keep their tap fallbacks (⚠️, acceptable).

---

## Verified signals (greppable, definitive)

- **Adaptive adoption:** `today, family, insights, settings, surveys, activity_runtime, toolkit` + (2026-06-01) `subjects`, `schedule` now use a responsive primitive (`Breakpoints` / `LayoutBuilder` / `FormFactor` / `ConstrainedBox`). The rest are single-column-but-capped (acceptable for forms/detail; richer multi-column is optional polish).
- **Ungated `dart:io` on a reachable path:** none remaining — `photos/photo_upload_queue.dart` (now `kIsWeb`-guarded + service skips it on web) and `entries/observation_form_screen.dart` (now `XFile.fromData`) were the two; both fixed 2026-06-01. Already-gated: `voice/*`, `surveys/survey_table_screen.dart`.
- **Native-only plugins (no desktop):** `camera`, `image_picker` camera source, `mobile_scanner` (vehicles/invites scan), `record` (voice mic). Their affordances now gate on `isMobileCapturePlatform` (`lib/shared/platform.dart`) so web/desktop never mount them — file-pick / manual-entry / "scan on your phone" fallbacks instead.
- **`MediaQuery.sizeOf` layout-branch smell:** `settings/team_screen.dart:247` (branches master-detail off ancestor size, not `LayoutBuilder`), `messages/message_thread_screen.dart` (benign bubble cap).

---

## What this rubric is NOT

The four-states / a11y depth per screen is [docs/SCREEN_RUBRIC.md](SCREEN_RUBRIC.md)'s
job; this scores **platform reach** (web/desktop/adaptive/pointer). The two
overlap on "States" — kept here as a coarse signal, deferring to the screen
rubric for the rigorous per-screen pass.
