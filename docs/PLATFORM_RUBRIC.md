# Platform Readiness Rubric

**How every feature fares on web + desktop, not just mobile.** This app is
phone-first; mobile gets the attention and web/desktop drift. This is the
scorecard that makes the drift visible and prioritizes the catch-up.

**Status:** first full pass 2026-06-01 (all 33 `lib/features/` folders read).
Living document — re-score a row when you touch its screens; add the date.

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
| schedule | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | Cohort **tabs** stretch full-width on desktop instead of the cohorts×time matrix (Maya's deferred grid); reorder/edit tap-only. |
| attendance | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | Single full-width roster at all widths (no master-detail); Present/Absent swipe-only (has inline-button fallback). |
| tasks | ✅ | ✅ | ⚠️ | ⚠️ | ✅ | Width-capped but stays single column on desktop; snooze/dismiss swipe-only (action-sheet fallback). |
| review | ✅ | ✅ | ⚠️ | ✅ | ⚠️ | Phone `PageView` is a narrow card in a wide void on desktop; **no error state** (load error → "all clear"). |
| **entries** | ❌ | ✅ | ✅ | ✅ | ✅ | **Web crash:** Cmd/Ctrl+V image-paste calls `getTemporaryDirectory()` + `File()` ungated (`observation_form_screen.dart:319`). Typing/save/library-upload are fine. |

### Roster & family

| Feature | Web | Desktop | Adaptive | Pointer/KB | States | Biggest web/desktop gap |
|---|:--:|:--:|:--:|:--:|:--:|---|
| groups | ✅ | ✅ | ✅ | ✅ | ✅ | Roster reflows 1→3 col via `ResponsiveGrid`; all states designed. |
| family | ✅ | ✅ | ✅ | ✅ | ✅ | `ResponsivePage` + `LayoutBuilder`; PDFs via signed URL + `url_launcher` (web-safe). |
| exports | ✅ | ✅ | ✅ | ✅ | ✅ | `printing` ships a web impl — `sharePdf` = browser download on web. |
| subjects | ✅ | ✅ | ⚠️ | ✅ | ✅ | **Weakest adaptive:** bare `ListView` w/ no max-width cap — the per-child timeline runs edge-to-edge on a 1920 desktop. Fix: wrap in `ResponsivePage`. |
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
| activity_runtime | ⚠️ | ⚠️ | ✅ | ⚠️ | ✅ | Camera games (photography/pattern) degrade to "No camera here" off-mobile w/ no upload fallback; host games have no arrow-key next/back for a presenter. |
| curricula | ✅ | ✅ | ⚠️ | ✅ | — | Static reference — single-column ListView stretches on desktop (no two-pane session list/detail). |
| kid_mode | ✅ | ✅ | — | ✅ | — | N/A surface — `Notifier` + centered PIN dialog. |
| runtime | ✅ | ✅ | — | — | — | Pure rule-engine logic, no UI — fully portable. |

### System & ops

| Feature | Web | Desktop | Adaptive | Pointer/KB | States | Biggest web/desktop gap |
|---|:--:|:--:|:--:|:--:|:--:|---|
| omnibox | ✅ | ✅ | ✅ | ✅ | ✅ | THE command surface — real Cmd/Ctrl+K, overlay centers at 640. Gap: overlay mic is a "coming soon" stub. |
| onboarding | ✅ | ✅ | ✅ | ✅ | ✅ | Forms centered (`ConstrainedBox` 480); offstage-TextField PIN supports paste/IME. Nit: PIN cells 44 dp (<48). |
| invites | ✅ | ⚠️ | ✅ | ✅ | ✅ | Share/QR-gen web-safe (`qr_flutter`, `share_plus` web fallback); the QR **scanner** is native camera (no desktop) — but redemption is code-entry, so it degrades. |
| supplies | ✅ | ✅ | ⚠️ | ✅ | ✅ | Web/desktop-safe + all states; single-column `ResponsivePage` leaves the right half empty — a tile inventory wants a grid on desktop. |
| settings | ✅ | ✅ | ⚠️ | ✅ | ✅ | Responsive form primitives, correct as a centered column — but stays single-column even >1200; a settings index/detail master-detail would use the space. |
| auth | ✅ | ✅ | ✅ | ✅ | ⚠️ | OAuth `redirectTo` from `Uri.base` — every web origin must be on Supabase's Redirect-URL allowlist or sign-in dead-ends on a blank page; no state taxonomy (just spinner+inline error). |
| vehicles | ⚠️ | ❌ | ✅ | ✅ | ✅ | List/detail web-safe + `ResponsiveGrid`; `/vehicles/scan` uses `mobile_scanner` (native camera — no desktop, web needs getUserMedia) and is offered to every user. |
| **photos** | ❌ | ❌ | ✅ | ✅ | ⚠️ | **Web crash:** offline-upload fallback `photo_upload_queue.dart` uses `dart:io` + `path_provider` ungated — a failed first upload throws instead of queueing (silent photo loss). Display is web-safe. No desktop camera. |
| voice | ⚠️ | ❌ | — | — | ⚠️ | Mic dictation `kIsWeb`-gated (web needs HTTPS+getUserMedia); no desktop mic story (`record` unverified on macOS/Win/Linux). Service layer, no UI. |

---

## Prioritized gaps (what "not up to date on web/desktop" actually is)

### P0 — Real web runtime crashes (fix first; both are ungated `dart:io`)
1. **photos** — `photo_upload_queue.dart` (`dart:io` + `path_provider`, reached from `photo_service.uploadAndPersist`'s catch block + boot `processQueue`). On web a failed first upload throws instead of queueing → **silent photo loss**. *Fix:* `kIsWeb`-gate the disk queue; on web, skip it (rely on retry, or an IndexedDB-backed store later).
2. **entries** — `observation_form_screen.dart:319` image-paste (Cmd/Ctrl+V → `getTemporaryDirectory()` + `File()`, ungated). *Fix:* gate the paste-image branch with `kIsWeb` and route to the library-upload path (the camera branch right above it is already gated this way).

### P1 — Native capture with no desktop story (works mobile, dead/degraded elsewhere)
3. **vehicles `/vehicles/scan`** + **invites QR scan** — `mobile_scanner`, native camera only. *Fix:* manual-entry fallback on desktop (invites already have code-entry; vehicles need a plate/VIN entry, or hide "Scan" off-mobile).
4. **photos `multi_shot_camera`** + **activity_runtime** photography/pattern camera — gated on web, but **desktop** (`kIsWeb` false) hits a camera plugin with no desktop impl (caught → "No camera here", but the tile shouldn't appear). *Fix:* offer a file-picker fallback; hide camera affordances when there's no camera.
5. **voice** mic — no desktop mic story; web needs HTTPS + getUserMedia. *Fix:* document the web HTTPS requirement; evaluate `record` on desktop or hide dictation off-mobile.

### P2 — Adaptive layout (the broad "phone column on a big screen" feel)
The single biggest pattern: **only 7 of 33 features adapt to wide screens.**
Worst-first:
- **subjects** — bare `ListView`, edge-to-edge on desktop → wrap in `ResponsivePage` (lowest-effort, highest-impact).
- **schedule** — the tablet cohorts×time **matrix** (Maya's deferred grid).
- **attendance** — master-detail roster on wide.
- **supplies**, **surveys (table)** — grid / multi-column for the tile/data walls.
- **settings**, **messages**, **tasks**, **curricula**, **review** — cap width / add a second pane.

### P3 — Pointer & keyboard (desktop polish; the host-on-laptop case)
- **activity_runtime host games + live_session** — a presenter driving This-or-That / Charades / the Board from a laptop has only mouse-click buttons. Add **arrow-key next/back + spacebar/R reveal**. (`math_runner` is the lone keyboard-good counter-example — Enter-to-submit.)
- **attendance / tasks** swipe-only, **captures** long-press multi-select — add hover/right-click/keyboard equivalents (each has a tap fallback today, so ⚠️ not ❌).

---

## Verified signals (greppable, definitive)

- **Adaptive adoption:** only `today, family, insights, settings, surveys, activity_runtime, toolkit` reference a responsive primitive (`Breakpoints` / `LayoutBuilder` / `FormFactor`). The other 26 folders are single-column by default (fine for forms/detail, suboptimal for lists/grids on desktop).
- **Ungated `dart:io` on a reachable path:** `photos/photo_upload_queue.dart`, `entries/observation_form_screen.dart` (paste branch). Gated (safe): `voice/*`, `surveys/survey_table_screen.dart`.
- **Native-only plugins (no desktop, web-conditional):** `camera` (photos, activity_runtime photography), `image_picker` camera source (pattern_maker), `mobile_scanner` (vehicles/invites scan), `record` (voice mic).
- **`MediaQuery.sizeOf` layout-branch smell:** `settings/team_screen.dart:247` (branches master-detail off ancestor size, not `LayoutBuilder`), `messages/message_thread_screen.dart` (benign bubble cap).

---

## What this rubric is NOT

The four-states / a11y depth per screen is [docs/SCREEN_RUBRIC.md](SCREEN_RUBRIC.md)'s
job; this scores **platform reach** (web/desktop/adaptive/pointer). The two
overlap on "States" — kept here as a coarse signal, deferring to the screen
rubric for the rigorous per-screen pass.
