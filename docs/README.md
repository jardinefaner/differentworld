# Different World — docs index

The fastest path to "where do I look for X." Every other file in
`docs/` is referenced here with a one-line "what's inside."

## Start here

| Doc | What's inside |
|---|---|
| **[PROJECT.md](PROJECT.md)** | One-sentence pitch + what this app IS. Read first if you've never seen the project. |
| **[APP_GUIDE.md](APP_GUIDE.md)** | The five ways to navigate, the chrome layer, omnibox modes, slash commands, voice, kid mode, feature index by VERB, and how this generalizes to other verticals (construction, healthcare, etc.) |
| **[ROADMAP.md](ROADMAP.md)** | What's still on the table + the prioritized order to ship things in. The inheritance file for future sessions — check here BEFORE asking "what's next?" |
| **[PERSONAS.md](PERSONAS.md)** | The three people we're building for — real names, real workflows, real friction. |

## Roles, abilities, and feature flags

| Doc | What's inside |
|---|---|
| **[CAPABILITIES.md](CAPABILITIES.md)** | The master catalog. Every capability key on Space / Member / Group / Subject, what each gates, defaults per role, and how runtime checks compose (Space → Member → Group → Subject; any layer can veto). |
| **[SCHEMA_AUDIT.md](SCHEMA_AUDIT.md)** | What's still childcare-specific at the Postgres layer + the migration design for multi-vertical readiness. Read before designing a non-childcare pilot. |
| Source of truth (code) | `lib/core/capabilities/capability_keys.dart` — typed string constants for every key + `RoleBundles.defaultsFor(role)`; `lib/core/vertical/labels.dart` — per-vertical UI labels |

## Architecture / data model

| Doc | What's inside |
|---|---|
| **[DOMAIN.md](DOMAIN.md)** | The domain model — entities, fields, relationships, lifecycle states. Reading order before touching schema. |
| **[NAMING.md](NAMING.md)** | Universal naming convention — Space / Member / Group / Subject / Entry. Engine-level vs UI-level naming rules. |
| **[../CLAUDE.md](../CLAUDE.md)** | Engineering runbook — 5 load-bearing invariants, the 6-place new-table checklist, known gotchas (auth.uid() null, "modified during build", PowerSync ambiguous Column, etc.), tooling permissions. |

## UX rules + decisions

| Doc | What's inside |
|---|---|
| **[UX_DECISIONS.md](UX_DECISIONS.md)** | Append-only log of UX rules the app holds itself to. Read before proposing a UX pattern that "feels" right but might violate a settled rule. |
| **[SCREEN_QA_MATRIX.md](SCREEN_QA_MATRIX.md)** | Per-screen × state × expectation table. What every screen MUST show in loading / empty / data / error states. Walk this before declaring a build shippable. |

## Operations + security

| Doc | What's inside |
|---|---|
| **[SECRETS.md](SECRETS.md)** | How API keys + sensitive config are handled now, and what NEEDS to change before external rollout (Edge Function broker pattern). |
| **[SCALE_PUNCH_LIST.md](SCALE_PUNCH_LIST.md)** | What to do BEFORE this app goes from one program to many. The blockers between "personal-dev" and "external rollout." |

## Reviewer / agent system

Source of truth: the agent definitions in `~/.claude/agents/`.

| Agent | What it does |
|---|---|
| `flutter-preflight.md` | Code-correctness orchestrator — spawns 9 specialist guards (lifecycle, state, async, platform, performance, security, build, flame, sync) in parallel. |
| `red-team.md` | Adversarial reviewer — scenario-based bug finding. Three personas (hostile, clueless, unlucky). |
| `ux-critic.md` | Fresh-user reviewer — IA, copy, discoverability, flow, density. |
| `review-council.md` | Council orchestrator — spawns Preflight + Red Team + UX Critic in parallel, then runs a SYNTHESIZER pass that catches cross-cutting issues no single reviewer caught alone. |
| `flutter-qa-gate.md` | The only agent allowed to declare a feature shippable — runs the real toolchain end-to-end (pub get + codegen + format + analyze + test + build). |

Council pattern documented in CLAUDE.md → "Review pipeline."

## Skills (agent-prescriptive patterns)

Live in `.claude/skills/`. The catalog index is at
`.claude/skills/index/SKILL.md` — 87 skills grouped by:
workflow, scaffolding, style rules (nav / data-sync / state /
widget hygiene / identity / quality), architecture references,
and process. Auto-load when their `description:` matches the
work the agent is doing.

Key skills for the categories users ask about most:

- **"How do I navigate / find things"** → `omnibox-modes`, `hamburger-menu`, `route-chrome`, `no-bottom-nav`
- **"How do roles / abilities work"** → `capabilities`, `viewer-lens`, `new-capability`
- **"How do I add a screen"** → `new-screen`, `new-route`, `golden-test`
- **"How do I add a feature that syncs"** → `new-table`, `architecture`, `offline-first`, `sync-add-table`
- **"What's not allowed"** → `no-app-bar`, `no-bottom-nav`, `offline-first` (covers no-direct-supabase), `no-pii-in-logs`, `no-magic-strings`, `no-print-statements`, `no-color-only`, `dont-git-add-dot`

## When you don't know what to read

Triage:

| Question | First open |
|---|---|
| "What does this app do?" | PROJECT.md, then APP_GUIDE.md |
| "What's next? What should I ship?" | ROADMAP.md |
| "Who am I building for?" | PERSONAS.md |
| "What can a {role} do? What does {capability} gate?" | CAPABILITIES.md |
| "Where does feature X live in the UI?" | APP_GUIDE.md → Feature index |
| "What should screen X show in state Y?" | SCREEN_QA_MATRIX.md |
| "Can this work for construction / healthcare / hospitality?" | APP_GUIDE.md → Part 2 |
| "How do I add a new table / capability / migration?" | CLAUDE.md → "Adding a synced table" + `new-table` skill |
| "Why does X behavior happen?" | CLAUDE.md → "Known gotchas" |
| "Where do API keys live? What's the security posture?" | SECRETS.md |
| "What rule am I about to violate?" | `.claude/skills/index/SKILL.md` |
| "Why does the AI keep doing X" | Probably a skill with auto-load. Search `.claude/skills/` for the pattern. |

## Maintaining this index

When you add a new file under `docs/`, add a row here in the right
section. When a file gets retired or replaced, mark it accordingly
(or delete the row + the file in the same commit).

When the docs catalog grows past ~15 files, refactor — categories
should not be longer than 5 rows each.
