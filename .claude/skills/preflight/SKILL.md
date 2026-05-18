---
name: preflight
description: Run the Flutter Preflight agent on recently changed files. Lifecycle / state / async / platform / performance / security / build / sync checks in parallel. Run before commits.
---

# /preflight — Flutter Preflight agent

The built-in **Flutter Preflight** agent spawns specialist guards in
parallel and synthesizes a single deduplicated report grouped by
severity (BLOCKER / WARNING / NIT).

## When to run

- After non-trivial code changes
- Before declaring a feature done
- Before any `/ship` cycle
- After a refactor that touched multiple files

## How to brief it

The agent doesn't see this conversation. Hand it a self-contained
prompt:

- What screens / files changed
- What feature this implements
- Specific concerns you want eyes on (security boundaries, sync paths,
  performance hot loops)
- Anything that's intentionally trade-off-y so it doesn't flag those

## Reading the output

| Severity | Action |
|---|---|
| BLOCKER | Fix before committing |
| WARNING | Fix if cheap; otherwise track in a TODO + commit message |
| NIT | Address if you're already in the file; otherwise skip |

The report also breaks down per-specialist (Lifecycle / State / Async /
Platform / Performance / Security / Build / Sync) — use that to route
follow-up agent calls if needed.

## When NOT to spawn it

- Pure docs / comment changes
- Cosmetic test edits
- README / CLAUDE.md tweaks
- Single-line typo fixes

## Pair with

- `ship` — preflight is step 3 of the ship checklist
- The dedicated guard agents (flutter-lifecycle-guard,
  flutter-state-guard, etc.) for targeted re-runs after fixes
