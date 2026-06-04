# Thinking Tools — the phased plan

Status: **design done → Phase 1 ready to start.** The north-star *why* lives in
[VISION.md](VISION.md) (dated 2026-06-03, "a library of distilled thinking
tools — one source of truth, many contributors"). This doc is the *how*: the
sequence that gets us there without a rewrite.

## The realization that shapes everything

The vision's pieces already exist in the repo as **separate features**, and
the contribution model is already *designed*. This is connective tissue + a
content decision, not a new engine.

| Vision piece | Already in the repo |
|---|---|
| Distilled reference, one canonical form, editorial voice | **`lib/features/toolkit/`** — 30 curated `ToolkitTool`s (`when / instead / tryThis / why / quick`), in-binary, offline-forever. The header argues the anti-YouTube case explicitly. |
| Runnable, not readable | **`lib/features/games/`** — 13 `GameDefinition`s + the live present/control engine (`docs/LIVE_SESSIONS.md`). |
| Distillation tiers, many contributors | **Designed** — the Toolkit's deferred *Wave 162* `toolkit_overrides` table (curated floor + per-space add / hide / override, keyed on stable slugs). The tiered-contribution mechanism. |
| Combinatorial, endless-fresh | The content engine (`content_engine.dart`, generators + `ContentMemory`). |

## The unifying model

A **Thinking Tool** = a **reference face** (the distilled "what it's for /
when to reach for it / one script") **+ an optional runnable face** (a
`GameDefinition` you launch with the room). Reference-only tools (a mental
model you recall), run-only tools, and both fit one shelf.

The v1 unification is an **adapter**, not a rewrite: a `ThinkingTool`
view-model that both `ToolkitTool` and `GameDefinition` map into. Nothing
existing gets deleted; the new library is a front door over both sources.

## The sequence

### Phase 1 — Unify into one library (foundation)
One `/tools` shelf listing both the 30 reference tools and the 13 runnable
games as searchable cards; each detail shows the reference face + a "Run with
the room" button when runnable.

- `ThinkingTool` view-model + adapters `ToolkitTool → ThinkingTool` (reference)
  and `GameDefinition → ThinkingTool` (runnable). Add light reference metadata
  to `GameDefinition` (`purpose` / `whenToUse`, defaulted) so games render a card.
- `/tools` library screen (reuse `FeatureCard`, the toolkit screen's search) +
  a detail screen. "Run with the room" → existing live route.
- Wire the **four discovery surfaces** (router / omnibox / nav / settings) and
  claim them in `docs/FEATURES.md`. Decide the fate of the standalone Toolkit +
  Games entry points (fold in vs keep).
- **Gate:** one shelf, both kinds discoverable + runnable; analyze + tests +
  Screen Rubric green.

### Phase 2 — Broaden the content ("for whatever you do")
Author universal thinking tools (Systems Thinking, First Principles, 5 Whys,
Inversion, Think-Pair-Share, Steel-manning, Second-order thinking…) in the
same contract — some reference-only, some runnable.

- New content section ("Thinking tools") alongside the classroom "teaching
  moves." In-Dart, editorial voice, like the toolkit.
- Runnable ones reuse existing shells (Discussions / Poll / As-If) or add small
  new `GameDefinition`s (5 Whys = a guided 5-step prompt; Think-Pair-Share = a
  3-phase timer). Lean on the content engine for freshness.
- **Open question:** audience framing — surfaced to teachers (who use these
  with kids AND for their own thinking), or a broader non-classroom mode?
- **Gate:** the library spans classroom moves + universal tools; ≥2 new
  runnable tools work live.

### Phase 3 — Open to contributors (one source of truth, many)
Generalize the designed `toolkit_overrides` so a space can add / hide /
override tools, then a promotion path from per-space → canonical.

- `tool_overrides` synced table (per-space, keyed on stable slug) — the
  six-place synced-table checklist applies.
- Authoring UI for reference tools first (runnable authoring is harder — defer).
- Curation/promotion: director-curated within a space first; cross-space
  editorial/community promotion + dedupe-by-fingerprint is the far end (its own
  big surface — identity, moderation).
- **Gate:** a space authors + uses its own tools; community promotion is the
  long tail.

## Cross-cutting
- Keep the `ThinkingTool` contract **domain-agnostic** (the app's engine/UI
  split) so "whatever you do" stays reachable.
- Combinatorial generation applies to runnable tools for never-stale instances.

## Open questions (carried from VISION.md)
- Audience: stays teacher-anchored, or genuinely broadens past the classroom?
- What earns a contributed tool the canonical slot (votes / editorial / usage)?
- Runnable contribution — author a new interaction, or only pick from existing
  shells?

## Current status / next
Branch `feat/thinking-tools`. **Phase 1 done; Phase 2 content shipped.**

- **DONE — Phase 2 content (broaden past the classroom).**
  `lib/features/tools/thinking_tools_catalog.dart`: `universalThinkingTools`,
  10 universal mental models / methods as reference cards in the same shape
  (First Principles, The 5 Whys, Inversion, Second-Order Thinking,
  Steel-Manning, Think·Pair·Share, Systems Thinking, Map-vs-Territory,
  Occam's Razor, 10/10/10). `buildToolLibrary()` now merges THREE sources
  (runnable + universal + Toolkit); tests updated. The library now spans
  classroom moves + universal thinking tools.
- **NEXT (Phase 2b) — RUNNABLE thinking tools.** Make ≥2 of the universal
  tools run with the room (a Think·Pair·Share 3-phase timer, a 5-Whys
  stepper) as small `GameDefinition`s — the "run it, don't just read it"
  payoff. And a category filter on `/tools` (runnable / thinking tools /
  teaching moves) since the flat shelf is now ~46 entries.


- **DONE — the unified model.** `lib/features/tools/thinking_tool.dart`: the
  `ThinkingTool` view-model + `ThinkingTool.fromToolkit` (reference adapter) +
  a curated `runnableThinkingTools` const list + `buildToolLibrary()`.
  `test/unit/thinking_tool_test.dart` (6 tests). A constructor assert enforces
  runnable ⇒ has a route.
- **DONE — the `/tools` screen.** `lib/features/tools/tools_screen.dart`: a
  searchable shelf of `FeatureCard` tiles over `buildToolLibrary()`; runnable
  tiles launch `tool.route`, reference tiles open a glass reading sheet
  (when / why / script). Width-capped for desktop; Screen Rubric passed (D2
  blocker + A4/A5/E2 warns fixed).
- **DONE — discovery wiring (4 surfaces) + FEATURES.md.** Router `/tools`,
  omnibox `page.tools`, `/tools` slash, nav "Tools" (Activities group), and a
  claimed `## Tools (Thinking Tools)` entry in `docs/FEATURES.md`.
- **NEXT — Phase 1 wrap + on-device pass.** Decide the fate of the standalone
  Toolkit (Settings) + Brain Breaks (nav) entry points — keep for now (the new
  shelf coexists), fold in later. Tap-through on the Pixel once it's back.
- **THEN — Phase 2 (broaden content).** See the Phase 2 section above.

### Notes for the build
- **Runnable source of truth (Phase-2 debt):** `runnableThinkingTools` is a
  small hand-curated list whose routes mirror the Brain Breaks deck
  (`activity_runtime/brain_breaks_screen.dart`, the `_BreakCard` const list —
  route-based, NOT `GameDefinition`s, and it mixes in pure brain-breaks like
  Breathe / Photo). Phase 2 should reconcile these into one source.
- **`GameDefinition`** (`games/game.dart`) has only `id / title / vibe(colors)
  / liveRoute` — no reference text — so we adapt from routes/curation, not from
  the contract. Add a `purpose` getter there if/when games need richer cards.
