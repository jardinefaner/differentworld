# The semantic graph — the app as nouns, not pixels

**Status:** design approved (2026-05-31). First slices queued (frame
prototype + rule-runtime seed).
**Origin:** "create a frame instead of a picture; each entity is a noun in
this world; the rules and actions are defined by its users." Designed for
efficiency and performance first.

**The one principle:** the app is a **graph of typed nouns**, and
everything else is a *view* of that graph. The screen is one view (the
**frame** — where each noun sits, in what state, with what actions). The
behavior is another view (the **rules** — what happens to a noun when the
world changes). We never reason about the app as pixels and we never
hardcode what could be a noun or a rule. Pixels are a render target;
nouns are the truth.

This extends [docs/NAMING.md](NAMING.md) (Space / Member / Subject /
Group / Entry — the data nouns) *up into the UI and behavior*: the same
noun that is a row in Drift is a node in the frame and a subject of
rules. One vocabulary, three projections.

---

## 1. The design

### Two layers, one graph

```
                    ┌──────────────────────────────┐
                    │      THE NOUN GRAPH           │   ← truth (Drift, local-first)
                    │  nouns + relations + rules    │
                    └───────────┬──────────────┬────┘
                                │              │
                  project to space│            │evaluate on change
                                ▼              ▼
                    ┌────────────────┐   ┌──────────────────┐
                    │   THE FRAME    │   │  THE RUNTIME     │
                    │ where + state  │   │ when/if/then     │
                    │ + actions      │   │ (reactive)       │
                    └────────────────┘   └──────────────────┘
```

- **The graph** is the model: typed nouns, their relations, and the rules
  that govern them. It lives in Drift, syncs through PowerSync, works
  offline — the existing architecture invariants hold unchanged.
- **The frame** is the on-screen projection: for every visible noun, its
  identity, its global rect, its state, and the actions it affords —
  computed *structurally* from the widget/semantics trees, never
  rasterized.
- **The runtime** is the behavioral projection: a reactive, indexed
  evaluator that fires a rule when a noun it watches changes.

"Where is each widget" and "what are the rules" are two reads of the same
graph.

### The frame — a structural snapshot, no screenshot

Flutter maintains three trees: Widget (config) → Element (lifecycle) →
**RenderObject** (geometry: `size` + `localToGlobal`). In parallel it
maintains the **Semantics tree** (meaning: label, role, the actions a
node affords, flags like focused/selected) — already built and kept live
for accessibility, which this app already invests in.

The frame rides both. A single wrapper makes it domain-aware:

```dart
NounScope(
  noun: 'ScheduleBlock',          // the type
  id: block.id,                   // the row it's bound to (nullable)
  actions: const ['tap','edit','delete'],
  state: {'editing': editing, 'tone': tone.name},
  child: _BlockTile(...),
)
```

`captureFrame()` walks the registered scopes, reads each one's RenderBox
rect, and returns:

```dart
UiFrame {
  size:  Size,                    // viewport
  at:    DateTime,
  nodes: List<UiNode>,
}
UiNode {
  noun:     String,               // 'ScheduleBlock'
  id:       String?,              // domain id when bound
  key:      String?,              // stable ValueKey if any
  rect:     Rect,                 // GLOBAL bounds (localToGlobal + size)
  state:    Map<String,Object?>,  // {focused, selected, editing, empty…}
  actions:  List<String>,         // what this noun affords HERE
  children: List<UiNode>,
}
```

A frame is a few KB of structured data; a screenshot is megabytes + a GPU
rasterize + a PNG encode. The frame is built on demand from trees that
already exist — there is no per-frame cost unless something asks for it.

### The runtime — nouns, rules, actions as data

- **Nouns as rows.** A `noun_types` catalog; instances are typed
  `entries` (the existing `kind + payload` pattern is already a generic
  noun). Core nouns (Space/Member/Subject/Group/Entry) stay first-class
  tables; user-defined nouns ride `entries`.
- **Rules as data.** `{ when: <trigger>, if: <condition>, then: <action> }`.
  The live-block auto-tag designed in
  [LIVE_BLOCK_CONTEXT.md](LIVE_BLOCK_CONTEXT.md) is the canonical first
  rule: *WHEN an Entry is created, IF a block is live, THEN set
  `entry.scheduleBlockId = liveBlock.id`.* What Wave C would hardcode is
  the worked example of an authorable rule.
- **Actions as data.** Named, parameterized mutations over nouns —
  `create`, `set`, `link`, `notify` — composed by the user, executed
  through the existing DAO layer (so every action is still a local-first
  Drift write that PowerSync uploads).
- **The evaluator is reactive + indexed.** Rules are indexed by
  `(nounType, trigger)`. A noun change consults only the matching rules,
  never the whole set. Triggers ride Drift change streams — no polling.

### How a user gets a rule without programming

Most users never author a rule. Rules are **captured from behavior**, in
the formless spirit: *"You've tagged 3 captures to Outdoor Play in a row —
always tag captures during a block to it? → [Make it a rule]."* The rule
is proposed from what they already did; authoring it is one tap. The raw
`{when/if/then}` editor exists for power users but is never the front
door.

---

## 2. The rules (invariants)

- **R0 — pixels are never truth.** No feature reasons about the UI by
  reading rendered pixels. Position/identity/state come from the frame
  (semantics + RenderObject), never from an image. Screenshots are for
  humans, not for logic or tests.
- **The graph is local-first.** Nouns, relations, and rules are Drift
  rows; they sync via PowerSync and work offline. No rule evaluation
  awaits a network round-trip. Every architecture invariant in CLAUDE.md
  applies to user-defined nouns exactly as to built-in ones (program_id
  on every synced table, uuid client-side, etc.).
- **Indexed, never full-scan.** A noun change evaluates only rules keyed
  to its `(nounType, trigger)`. A ruleset that grows must not slow a
  single write.
- **Reactive, never polling.** Triggers are Drift stream events. Nothing
  ticks to "check if a rule should fire."
- **The vocabulary stays small and domain-shaped.** Conditions and
  actions are a closed, auditable set (comparisons, links, sets,
  notifies) — NOT a Turing-complete language. If a rule needs real
  computation, it's a hardcoded capability, not a user rule. This is the
  guard against the inner-platform effect.
- **The hot path stays compiled.** Latency-critical flows (the live-block
  tag, attendance) run as native code but are *expressible* as the
  canonical rule, so there is one mental model. The runtime owns the long
  tail, not the 16 ms path.
- **Frame nodes are bound by id, not by pixel.** A `NounScope` carries
  the domain `id`; the frame keys on `(noun, id)`. Re-layout, scroll, and
  resize move a node's rect but never its identity.
- **PII discipline is unchanged.** A frame may carry a noun's `id` and
  structural state; it must NOT carry child names, photos, or narrative
  payloads. The frame is shape, not content. (No PII in logs still
  holds — a frame dumped to a log must be safe.)

**Two load-bearing ideas:** resolve *where* from the live tree (an
explicit capture, never a stale cached layout), and resolve *behavior*
from the graph (a rule over nouns, never a one-off hardcoded `if` that
the next surface won't know about).

---

## 3. The acceptance rubric

Pass/fail. "Frame" = the structured snapshot. "Noun" = a typed entity in
the graph. "Rule" = a `{when/if/then}` row.

**Frame correctness**
- ☐ Every `NounScope` on screen appears exactly once in the frame with a
  non-empty `rect` inside the viewport (or marked off-screen).
- ☐ A node's `rect` equals its RenderBox `localToGlobal(Offset.zero) &
  size` at capture time (matches what a screenshot would show, to the
  pixel — verified once, by overlay, then trusted structurally).
- ☐ `(noun, id)` is stable across scroll/resize; only `rect`/`state`
  change.
- ☐ The frame carries no PII (names, photo bytes, narrative text).
- ☐ Capturing a frame allocates no image buffer and triggers no repaint.

**Frame performance**
- ☐ A full-screen frame capture is < 2 ms on a Pixel 6 and produces < 16
  KB of JSON for a dense screen.
- ☐ Capture does not force a layout/paint pass that wouldn't otherwise
  happen.

**Runtime correctness**
- ☐ The live-block auto-tag, expressed as a data rule, produces a tag
  identical to the hardcoded path on the same inputs.
- ☐ A noun change evaluates only rules indexed to its `(nounType,
  trigger)` — proven by a counter, not by inspection.
- ☐ A rule action is a local-first Drift write (offline-safe, optimistic,
  uuid client-side) — never a direct Supabase call.
- ☐ A malformed/loops-on-itself rule cannot wedge the evaluator (cycle
  guard + per-change fire budget).

**Trust + forgiveness**
- ☐ A captured rule is shown in plain language before it's saved
  ("Always tag captures during a block to that block").
- ☐ Any rule is reversible — disabling it stops future fires and never
  rewrites past data.
- ☐ A rule never deletes content as a side effect; destructive actions
  route through `confirmDestructive`.

---

## 4. What this unlocks

All on the same graph.

1. **Screenshot-free verification.** The agent and the test suite read the
   frame, not pixels — structural assertions ("5 cohort columns, each ≥
   200 dp at tablet width") replace font-fragile goldens (the exact
   flakiness hit twice this week).
2. **The live-block feature becomes the first rule** instead of a
   one-off — and every future "when X then tag/notify/link" is the same
   machinery.
3. **Director-authored automation** — "when a field-trip block goes live,
   notify the office"; "when a kid has 0 captures by 2 pm, flag it" —
   without a code change.
4. **A self-describing UI** — onboarding, help, and "what can I do here?"
   read the frame's `actions` per noun. The app can explain itself.
5. **Layout assertions as data** — responsive-breakpoint rules become
   checkable facts about the frame, not screenshots per device.
6. **The showcase / growth-arc curation** (deferred vision) gets a
   substrate: "moments" are nouns; "include in this week's showcase" is a
   rule + action over them.

---

## 5. The build seed

Two minimal slices, each proving one feel, each landing as its own wave.

**Slice 1 — the frame (Wave: SG-frame).**
- `NounScope` widget (`lib/shared/semantics/noun_scope.dart`) — an
  InheritedWidget-backed registry + a marker RenderObject so a walker can
  find every scope and read its rect.
- `captureFrame()` + the `UiFrame`/`UiNode` value types
  (`lib/shared/semantics/ui_frame.dart`).
- Pilot: wrap each `_BlockTile` in the schedule screen. Prove a test can
  assert "the `ScheduleBlock` for id X is at rect Y, state editing=true"
  with no screenshot, and replace one flaky golden with a frame
  assertion.
- Stretch (no new code): on Flutter web, the semantics DOM + the Preview
  MCP tools (`preview_snapshot`/`preview_inspect`) read the frame *today*
  — a zero-build validation that the structural approach carries.

**Slice 2 — the rule-runtime seed (Wave: SG-runtime).**
- The noun/rule value types + a 50–80 line reactive evaluator
  (`lib/features/runtime/`), indexed by `(nounType, trigger)`.
- Express ONLY the live-block auto-tag as a `{when/if/then}` rule, run it
  through the evaluator, and assert it produces the identical tag to the
  hardcoded path. Validates the runtime against a known-good behavior
  before any of the app commits to it.
- No user-facing rule editor yet, no new synced tables yet — the seed
  proves the evaluator with in-memory rules first; persistence + the
  six-place synced-table checklist come only once the feel is proven.

If both feel effortless — the frame is precise and cheap, the rule
reproduces the hardcoded behavior — then user-defined nouns, the
propose-a-rule capture flow, and everything in §4 are mechanical
extensions of the same graph.
