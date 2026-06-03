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
- **Design done; Phase 1 not yet started.** Branch `feat/thinking-tools`.
- **First concrete step** (fresh-context-friendly, ~1 commit): the
  `ThinkingTool` view-model + the two adapters (`ToolkitTool → ThinkingTool`
  reference; `GameDefinition → ThinkingTool` runnable) + a unit test proving
  both sources map to one shape. Pure Dart, no UI — de-risks the unification.
- **Then:** the `/tools` library screen (reuse `FeatureCard` + the toolkit
  screen's search) + a detail with "Run with the room" → existing live route.
- **Then:** wire the four discovery surfaces + claim them in `docs/FEATURES.md`.
- **Spelunking note for whoever builds it:** the games registry isn't a single
  central list — games are enumerated in `present_hub_screen.dart` (the present
  hub). Start there to get the iterable set of `GameDefinition`s; the reference
  set is the const `toolkitCatalog` in `toolkit/toolkit_catalog.dart`.
  `GameDefinition` has `id / title / vibe / liveRoute` but NO reference text yet
  — derive a blurb from title+vibe for v1, or add an optional `purpose` getter.
