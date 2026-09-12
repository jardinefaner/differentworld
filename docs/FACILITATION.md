# The facilitation engine — what the screen knows

> **The screen is not primarily for the child. It is the shared state of
> the room.** — [VISION.md](VISION.md), 2026-09-12

This is the architecture for that sentence. [PRIMITIVES.md](PRIMITIVES.md)
says what the ROOM does (eleven atoms — Verb, Pick, Circle, Timer…). This
says what the SCREEN holds so an adult can run it.

**It is not a twelfth primitive**, and the distinction is load-bearing: the
atoms are the children's experience; facilitation is the adult's coordination
layer *underneath* them. A Circle is an atom. Knowing whose turn it is inside
that circle, how long is left, and what happens when it ends is facilitation.
Confusing the two is how you end up with a twelfth atom that is really a
scheduler.

---

## The contract — six questions, one read-model

Everything here exists to answer exactly these, at any moment:

| # | The question | The facet |
|---|---|---|
| 1 | What are we doing? | `doing` |
| 2 | What step are we on? | `step` |
| 3 | Who's involved — and whose turn is it? | `who` · `turn` |
| 4 | What happens next? | `next` |
| 5 | What can the adult change, right now? | `moves` |
| 6 | What should be remembered afterward? | `keep` |

A facilitation surface **reads** these. It does not re-derive them. That is
the whole rule, and it is what the engine buys.

---

## What already exists (surveyed 2026-09-12)

The pieces are real and individually well-built. **This is not a rewrite.**

| Facet | Already owned by | State |
|---|---|---|
| `doing` | `LiveBlock` — `lib/features/schedule/live_block_provider.dart` | **Solid.** Knows block, group, kind, outdoor, start/end. Already stamps captures automatically. |
| `step` | Three separate shapes: `GridBoard` wire `i`/`n`; `SessionScript` beats; activity slide indices | **Fragmented.** Same concept, three encodings. |
| `who` | `present_today.dart` (who is actually here) | **Solid**, but not read by activity surfaces. |
| `turn` | Four independent implementations — see below | **The real gap.** |
| `next` | `now_next_strip.dart`, `live_block_provider` | **Solid.** |
| `moves` | The per-block "use right now" tray in `block_run_sheet_screen.dart` | **Solid but local** — only the block sheet has it. |
| `keep` | `captures` / `entries`, already stamped by `LiveBlock` | **Solid.** The best-composed facet today, and the model for the rest. |

### The turn problem, stated precisely

Four things answer "who's up" and none of them know about each other:

- `GridGame.turn` + `alternates` — two sides, flip on a move
  (`lib/features/games/grid_game.dart`)
- `picker_logic.dart` — a fair bag: **everyone before anyone repeats**,
  persisted, re-synced against the eligible roster
- photo turns — per-child turn through a roster in a session
- `rotation_engine.dart` — pair-history-aware grouping

**These are not duplicates and must not be merged.** Fair-draw, side-alternation
and pair-history grouping are genuinely different algorithms with different
correctness conditions. Merging them would destroy the thing each is good at.

What they share is a **role**, not an implementation: *something that names who
is up, and advances*. That role is the seam.

---

## The design

### 1. `RoomState` — a composed read-model, not a new store

```dart
/// What the screen knows, right now. COMPOSED from the providers that
/// already own each facet — it stores nothing of its own, so there is no
/// second source of truth to drift.
class RoomState {
  final LiveBlock? doing;      // facet 1
  final Steps? step;           // facet 2
  final List<Subject> who;     // facet 3 — present, not enrolled
  final TurnHolder? turn;      // facet 3
  final LiveBlock? next;       // facet 4
  final List<Move> moves;      // facet 5
  final KeepTarget keep;       // facet 6
}

final roomStateProvider = Provider.autoDispose<RoomState>(...);
```

**Why composed, not stored:** every facet already has a correct owner with its
own sync story. A new table would be a second truth that can disagree with the
first — the exact failure this codebase has already paid for elsewhere. The
engine's value is *assembly*, not custody.

### 2. `TurnSource` — one role, several algorithms

```dart
/// Something that knows who is up. The ALGORITHM varies; the role does not.
abstract class TurnSource {
  TurnHolder? get current;
  TurnSource advance();          // pure — returns the next state
  String get label;              // "Team 1 to play" / "Amara's turn"
}
```

Implementations wrap what already exists rather than replacing it:

| Implementation | Wraps | Rule it preserves |
|---|---|---|
| `AlternatingSides` | `GridGame.turn` | two sides, flip on an accepted move |
| `FairDraw` | `picker_logic.dart` | everyone before anyone repeats |
| `RosterOrder` | photo turns | each child once, in order |
| `NoTurn` | — | the room acts as one (the honest default) |

**What this buys:** any activity can say *"take turns"* and get the whose-go
line, the label and the advance rule without writing one. It is the single
change that makes facilitation composable — and it is why `alternates` on a
`GridGame` should eventually BE an `AlternatingSides`, not a parallel concept.

### 3. `Steps` — one shape for "where are we"

```dart
class Steps {
  final int index;      // 0-based
  final int total;
  final String? label;  // "Slide 3 of 8" / "Beat 2 — the demo"
}
```

Games encode this as wire `i`/`n`; scripts as beats; activities as slide
indices. One value type, three adapters, and the day strip / cast screen /
control bar stop each knowing three formats.

---

## The rules (with teeth, eventually)

1. **A facilitation surface reads `RoomState`. It does not re-derive a facet.**
   If you are about to compute "who is here" or "what block is live" inside a
   screen, the engine already knows.
2. **Turn-taking goes through `TurnSource`.** A new activity that rolls its own
   whose-go is the defect this engine exists to prevent. There are already four;
   a fifth is not a feature.
3. **`RoomState` composes; it never stores.** No table, no cache that can
   disagree with the owner of a facet.
4. **A facet with no owner is a gap, not a licence to invent.** Name it here
   first.

A checker (`scripts/check_facilitation.sh`) should eventually assert #2 by
failing on a new `turn`/`whoseTurn` field outside `TurnSource` implementations —
the same shape as the theme and spacing guards. Not written yet; noted so it is
a decision rather than an omission.

---

## Migration — incremental seams, nothing rewritten

The order matters: each step is independently useful and independently
revertible.

1. **`Steps` + adapters.** Lowest risk, no behaviour change, immediately
   removes three encodings of one idea.
2. **`TurnSource` + `NoTurn`/`AlternatingSides`.** `GridGame` adopts it behind
   its existing `alternates` API, so no game file changes.
3. **`RoomState` read-model** composed from the providers above. New surfaces
   read it; existing ones are untouched until they have a reason to move.
4. **`FairDraw` / `RosterOrder`** move behind `TurnSource`, unchanged in
   behaviour, pinned by their existing tests.
5. **`moves` generalised** out of the block-run sheet, so any surface can offer
   "what you can change right now."

**What this explicitly does NOT do:** merge the picker's bag with the games'
alternation, introduce a table, or rewrite a working feature to fit a diagram.

---

## Why this is the architecture the thesis implies

The thirteen headaches in VISION.md are almost all *coordination*, not content:
transitions, who goes first, how long, what the finisher does next, and
knowledge that leaves with a person. Each is a facet of the six above going
unanswered, and each is currently answered by a counselor's memory.

The moat follows from the same seam: once facilitation is a named layer rather
than a habit spread across screens, the patterns that work in **this** program
can accumulate in it. A content library is copyable. A record of how
facilitation actually works here is not.
