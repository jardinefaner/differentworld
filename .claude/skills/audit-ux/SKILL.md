---
name: audit-ux
description: Spawn the general-purpose agent to audit current UX state and surface friction / polish opportunities. Use periodically as the surface grows.
---

# /audit-ux — surface UX gaps

Spawn the **general-purpose** agent with a self-contained prompt that:

1. Names the app (Different World, classroom-mgmt, mobile-first)
2. Lists every screen currently built (paths in `lib/features/`)
3. Walks the primary flows (director onboarding, teacher morning routine,
   invite acceptance, photo upload)
4. Asks for findings in three buckets:
   - **Friction fixes** — small-medium implementation, big daily-use impact
   - **Polish** — cheap touches that compound
   - **Bigger bets** — meaningful redesigns

End with: "If we could do exactly ONE thing in the next session, what's
the single highest-leverage move?"

## Inputs to give the agent

- A complete file listing under `lib/features/`
- The most recent commits / shipped features
- What's documented as "intentionally deferred" so the agent doesn't
  re-rediscover known TODOs
- Specific concerns from the user if they have any

## Output to look for

- Each finding cites file:line
- Findings are ranked not listed
- The 10–15 highest-impact items, not 50 vague observations

## Pair with

- After the audit, spawn the flutter-preflight agent on any specific
  fixes to verify they don't regress anything
- If the audit surfaces a layout / motion bug, follow with a
  `screenshot-pixel` to compare before/after

## Pattern (from session history)

The previous /audit-ux surfaced 7 friction fixes + 7 polish + 4 bigger
bets, and the single recommended move was "build Morning Checklist as
Today's primary surface". That model — concrete, opinionated, ranked —
is what good audits look like.
