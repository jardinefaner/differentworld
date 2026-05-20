---
name: index
description: Catalog of every skill in this repo grouped by category. Use to discover what's available before starting work.
---

# Skill index — 87 skills

## Workflow / dev commands (13)

- `ship` — pre-ship checklist (analyze + test + preflight + commit + push)
- `run-pixel` — launch on the Pixel 6 wireless (default target)
- `run-profile` — Pixel in profile mode (AOT, for feel-testing)
- `run-web` — Chrome on port 3000
- `clean` — flutter clean + pub get
- `regen` — build_runner build
- `wipe-pixel` — uninstall + reinstall fresh local DB
- `push-db` — supabase db push
- `screenshot-pixel` — adb screencap
- `pixel-log` — adb logcat filtered to the app
- `deep-link-test` — fire an invite deep link via adb
- `preflight` — Flutter Preflight agent
- `audit-ux` — spawn a UX audit agent

## Scaffolding (9)

- `new-screen` — EdgeScaffold-based screen template
- `new-form-sheet` — bottom-sheet form with DismissGuard + DestructiveButton
- `new-table` — 5-place synced-table checklist
- `new-migration` — timestamped SQL migration template
- `new-provider` — Riverpod 3 stream / family / actions templates
- `new-route` — register a go_router route
- `new-capability` — add a capability key + doc
- `add-drift-column` — extend an existing synced table
- `golden-test` — add a screen to the visual regression matrix

## Style / preference rules (45+, auto-applied)

### Navigation chrome
- `hamburger-menu` — drawer lives in AppShell (top-left when no back arrow)
- `route-chrome` — persistent top chrome rendered by AppShell from a stack
- `no-bottom-nav` — no Material BottomNavigationBar; omnibox composer is NOT a nav bar
- `no-app-bar` — no Material AppBar
- `edge-to-edge` — EdgeScaffold on every screen
- `in-content-titles` — titles via ContentHeader
- `floating-back-only` — never hand-rolled back button
- `glass-pill-actions` — top-right action pill via EdgeScaffold.actions
- `cupertino-transitions` — global iOS slide
- `push-not-go` — drill-in via context.push
- `edge-of-edge-status` — system UI overlay style per theme
- `safearea-top-only` — SafeArea(bottom: false) for edge-to-edge

### Omnibox / spine
- `omnibox-modes` — search / capture / slash + voice via Deepgram
- `kid-mode` — opt a screen into the locked-down kid surface

### Data / sync
- `typed-drift-only` — no customStatement for mutations
- `local-first-reads` — Drift streams, never Supabase from UI
- `no-direct-supabase` — three documented exceptions only
- `optimistic-writes` — local commit, async upload
- `never-await-network-handler` — same rule, restated
- `space-id-everywhere` — every synced table carries space_id
- `uuid-clientside` — IDs generated in Dart via Uuid().v4()
- `photo-via-storage` — binary media bypasses PowerSync; private bucket + signed URLs
- `sync-status-indicator` — the only place online/offline is shown

### State / providers
- `auto-dispose-family` — StreamProvider.autoDispose.family<...>
- `select-not-watch` — ref.watch a slice, not the whole object
- `read-in-callbacks` — ref.read in onPressed, not watch

### Widget hygiene
- `prefer-const` — const everywhere it compiles
- `list-builder-not-children` — ListView.builder for variable lists
- `mounted-after-await` — `if (!mounted) return;` after every await
- `no-jank-on-build` — CPU work in providers / isolates, not build()
- `fab-clearance` — 96 dp bottom padding on lists with a FAB (rarely needed
  now; AppShell already pads 76 for the omnibox bar)
- `responsive-breakpoints` — FormFactor.fromWidth, never MediaQuery.size

### Identity / forms
- `person-avatar` — every person renders via PersonAvatar
- `dismiss-guard` — form sheets > 3 fields wrap in DismissGuard
- `destructive-confirm` — confirmDestructive + DestructiveButton
- `empty-state` — designed empty path with icon + copy + CTA
- `intl-dates` — DateFormat, never hand-rolled day/month tables

### Quality
- `no-magic-strings` — typed constants for caps / roles / status
- `no-pii-in-logs` — student / parent / token / deeplink data stays out of
  release logs (gate with `if (kDebugMode)`)
- `no-print-statements` — debugPrint, not print
- `no-color-only` — signal state with icon + label + position
- `a11y-basics` — semantic labels, contrast, dynamic type
- `haptics` — selectionClick / mediumImpact / heavyImpact
- `copy-tone` — direct, specific, action-oriented copy
- `google-only-auth` — single "Continue with Google" button

## Architecture / domain references (11)

- `architecture` — 5 load-bearing invariants
- `file-size` — soft/hard caps + how to split
- `feature-folder` — canonical layout under lib/features/<noun>/
- `cross-platform` — web/desktop/mobile compat patterns
- `shared-helpers` — pointer to lib/shared/ (LoadingSlot,
  requireSpaceId, pickSubject, relativeTimeAgo, …)
- `split-dao` — DriftAccessor recipe for shrinking app_database.dart
- `gotchas` — known platform / dep traps
- `capabilities` — JSONB caps system reference
- `universal-naming` — engine vs UI terms
- `sync-add-table` — full 12-step rename sequence
- `list-routes` — every registered route

## Process (6)

- `wave-pattern` — multi-feature batches → multi-commit waves
- `commit-message-style` — subject + why-body + Co-Authored-By
- `dont-git-add-dot` — stage specifically, never -A
- `test-widget-pattern` — widget test setUp boilerplate
- `keep-claude-md` — append to CLAUDE.md when learning anything new
- `cleanup-tree` — decision tree for which reset to run

## How they get invoked

- **Slash commands**: `/<skill-name>` in chat invokes the named skill
- **Auto-load**: Claude reads the descriptions and pulls relevant skills
  into context when their `description:` matches the user's request or
  the code being edited

The auto-load is why we wrote rich descriptions — "Triggered when X" tells
Claude when this skill applies.

## What changed in this revision

- **NEW**: `route-chrome`, `omnibox-modes`, `kid-mode`, `golden-test`
- **REWRITTEN**: `hamburger-menu` (drawer is in AppShell, not per-route),
  `no-bottom-nav` (clarify the omnibox composer isn't a nav bar),
  `photo-via-storage` (private bucket + signed URLs), `new-screen`
  (no manual bottom padding for the bar; chrome publishes automatically)
- **OBSOLETED**: `no-hamburger` removed from the list (the drawer exists
  now); see `hamburger-menu` for the new home

The chrome / omnibox / privacy / kid-mode patterns landed in
commits `7a8a246` → `bc92131`. CLAUDE.md's "Composer / chrome
architecture" section is the runbook companion to these skills.
