---
name: wave-pattern
description: For multi-feature batches ("do all of these"), implement in waves with a commit between each. Triggered when the user requests a large batch of changes.
---

# Wave pattern for multi-batch work

When the user asks for "all" of a set of fixes, ship in 2-5 thematic
waves with a commit between each. Don't try to land everything in one
massive commit.

## Why

- **Reviewable history** — each commit is one cohesive change
- **Rollback granularity** — one wave can be reverted without losing
  others
- **Test as you go** — `flutter analyze` + `flutter test` between
  waves catches regressions early
- **Mental load** — easier to keep state in your head one wave at a
  time

## Pattern

1. **Plan the waves** — group by theme + risk
2. **Wave N**: implement → analyze → test → commit → push
3. **Wave N+1**: repeat

## Example from session history

UX waves shipped as 4 commits:
- Wave 1 (commit `1eae747`): quick fixes + polish — date clamp, split
  switches, haptics, intl, omnibox icon
- Wave 2 (commit `66de190`): destructive actions across all entities
- Wave 3 (commit `fb45aca`): program name in AppBar + search icon
- Wave 4 (commit `78dabfe`): Morning Checklist + bulk inserts

Each wave had its own preflight pass. The wave-4 preflight caught a
sync correctness issue (partial-load FAB) that wouldn't have been
visible in a single mega-commit.

## How to plan waves

Group by:
- **Theme** — "all friction fixes", "all polish", "the big screen"
- **Risk** — low-risk first (formatting, copy) → high-risk last
  (new screens, RLS, schema)
- **Touch scope** — files-overlapping waves can't be parallel; keep
  them sequential

## When NOT to wave

- Single-line fixes
- Trivial copy edits
- Anything atomic that can't be split (rename + all callsites)

## After the last wave

Update CLAUDE.md if anything new was learned. Tell the user what
was shipped + what's deferred for the next session.
