---
name: keep-claude-md
description: When you burn a turn on a non-obvious gotcha or settle a convention, append it to CLAUDE.md. Triggered after diagnosing a sneaky bug or making a cross-cutting decision.
---

# Living document discipline

CLAUDE.md is the single inheritance for every future agent / session.
Every gotcha that bit us has a paragraph there. Every convention has
a section. Don't let lessons evaporate.

## When to append

- Spent a turn debugging something non-obvious
- Made a cross-cutting decision that someone else will want to find
- Introduced a new pattern that diverges from convention
- Discovered a workaround for a platform / dep gotcha
- Deferred something explicitly (add to "intentionally deferred")

## Where to add

- **Known gotchas section** — for "we hit X, the symptom was Y, the
  fix is Z"
- **Cross-cutting standards** — for new conventions (e.g. "every
  screen uses EdgeScaffold")
- **Tooling permissions granted** — for new `Bash` grants
- **What's intentionally deferred** — for documented out-of-scope items

## Format

Match the existing voice — direct, technical, second-person OK, code
blocks for symptoms, fenced blocks for fixes. Don't bury the lede;
the first sentence of each gotcha should be the symptom or the rule.

## When NOT to append

- "Today I learned that Flutter has FloatingActionButton" — not a
  gotcha, just docs
- Things specific to one feature that aren't cross-cutting
- Things that change every week (those go in TODOs / commits)

## Trigger

After resolving any of these, ask yourself "would the next agent need
to know this?" If yes, append.

## Example entries

See the existing "auth.uid() returns null in REST requests" block —
that's the gold standard. Symptom, root cause, current workaround,
proper fix (deferred). Three paragraphs.
