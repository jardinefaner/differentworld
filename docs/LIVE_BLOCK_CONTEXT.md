# Live-block capture — moments tie to the live schedule block

**Status:** design approved (2026-05-31). First slice in progress.
**Origin:** senior-UX design workflow (`live-block-context-design`) — grounded
in the real capture/schedule model, four design lenses, one synthesis.

**The one principle:** the live block is *ambient context the counselor never
asserts*. Tagging is the default state of the world, not an action. We spend
taps only on *correcting* a wrong guess — never on confirming a right one. A
counselor mid-activity has one hand and three seconds. The day tags itself;
they look up at the end and it's already a timeline.

---

## 1. The design

### The live chip — on the omnibox bar, not buried in a card
"Live" today is logic trapped inside one widget (`NowNextStrip`), one scroll
deep into Today. Wrong altitude. The live context rides the **bottom omnibox
bar** — the one surface already on every screen, at thumb height, the capture
spine.

A slim strip sits directly above the omnibox bar (same glass,
`GlassPanelShape.bar`, ~36 dp, one line):

```
┌─────────────────────────────────────────────┐
│ 🟢 LIVE · Outdoor Play          ⊕ 3 moments  │  ← live strip (tap target)
├─────────────────────────────────────────────┤
│  [+]  Search or capture…           🎤        │  ← existing omnibox bar
└─────────────────────────────────────────────┘
```

- Left: a slow-breathing green dot + `LIVE · {block title}`. The word "LIVE"
  AND the pulse carry meaning (never colour alone). `RepaintBoundary` the dot.
- Right: `⊕ N moments` — running count for *this* block + the tap target to
  review them.
- **No live block → the strip collapses to zero height.** Absence is the
  signal; no "nothing live" copy.

Needs a real `liveBlockProvider` (none exists today): fans out over the
viewer's **assigned** groups (not a hardcoded `groupId`), filters
`status == planned` and `kind ∉ {break, closed}`, resolves overlap by
**most-recently-started**, ticks on a **30s timer**. Returns a small
`LiveBlock?`.

### Capture inherits the block — silently, with a persistent undo
Every capture path (omnibox `+`, photo, dictation, observation) stamps the
resulting entry's `scheduleBlockId` from the live block at write time. **No
confirm dialog** — the counselor is physically *in* the activity, so the guess
is right ~95% of the time; correction moves *after*, where it costs nothing.

The tag surfaces the instant the capture lands, on the confirmation already
shown:
- Omnibox / photo / mic → toast: **`Saved → Outdoor Play` · Change**
- Observation form → chip under the title: **`→ Outdoor Play ✕`**

**Override** (≤2 taps, only when wrong): a glass sheet of today's blocks for the
group, current one checked, **"No block (untagged)"** one tap, **"Earlier
today ▸"** for late logging. Reuses the existing day stream.

No block live → silently untagged (`scheduleBlockId = null`), toast `Saved`.
Absence is never a blocker, never a forced picker.

### Override before the shutter on the hero path
The `+` (when a block is live) opens the quick-capture menu **already bound**:

```
        ┌──────────────────┐
        │  → Outdoor Play   │  ← context header, tappable = override
        │  📷  Photo         │
        │  🎤  Voice note    │
        │  📝  Note          │
        │  👁  Observation   │
        └──────────────────┘
```

`+` → 📷 → shutter = a tied photo, **zero extra taps**. The block is
snapshotted into the capture flow at **menu-open**, not re-read at save — open
the camera at 2:59 (Outdoor Play), shutter at 3:01 (now Snack), the photo still
ties to **Outdoor Play**. *The moment belongs to what you were doing, not the
clock-tick you hit save.*

### The block as timeline
- **(a)** The live strip's `⊕ N` ticks up the instant a tied capture lands.
- **(b)** Tap the strip → a glass moment sheet (`showGlassSheet`), captures
  newest-first as `FeatureCard` rows (256 dp photo thumbs), **`+ Add a moment`**
  at the bottom (bound to that block even after it stops being live).
- **(c)** Every block tile (schedule grid + Today card) gains a **`📷 N`**
  moment badge. Tap any tile — live or past — opens the same sheet scoped to
  that block. A block is a thing you tap to see its moments.

---

## 2. The rules

- **R0 — the tie is a suggestion:** pre-filled, one-tap editable, never
  blocks/errors/delays a capture. It decorates; it never gates.
- **No block live → `null`.** Never fall back to last/next/nearest. Null is
  honest and searchable (entry still carries group + time).
- **Overlapping →** subject's group → author's assigned group →
  most-recently-started, with alternates as one-tap chips. Never silent
  first-match; never drop a concurrent block.
- **Wrong block →** editable chip; re-tag rewrites only `scheduleBlockId`.
  Do **not** auto-correct the schedule from a capture — planned and actual may
  disagree.
- **Retroactive →** tie to **capture time** (photo timestamp), not save time.
  Text-only late logging ties to now but flags staleness.
- **Ran long past `endAt` →** ~15 min **grace** suggests the just-ended block,
  but a **started successor always wins**. Never mutate `endAt`.
- **Group vs subject →** block ⟂ subject. One kid = block + subject. Whole
  group = block + group (subject `null`, cohort feed only). Several kids = one
  entry per subject sharing the block (bytes live once in Storage). Block =
  "during what?"; subject = "about whom?" — never collapse them.
- **Skipped/cancelled/break/closed spanning now →** not auto-tagged; still
  manually selectable.
- **Specialist with no home block →** subject drives the tie; else the block
  they `leadMemberId`; else `null` + pick-the-room chips.
- **Captures stay clean pre-triage →** block lands on the **entry** at
  create/promote, never on the `captures` row.

**Two invariants:** resolve against the moment's **real timestamp** (an
explicit `at:` arg), never `DateTime.now()` deep in `build()`. And
**null-by-default, corrected upward, never guessed downward** — a confident
wrong tie poisons cohort feeds and family timelines; an honest null + a cheap
nudge does not.

---

## 3. The acceptance rubric

Pass/fail. "Tagged" = `entries.schedule_block_id` set. "Live block" = cohort
block where `start <= now < end`, `status == planned`, `kind ∉ {break,
closed}`.

**Correctness**
- ☐ One block live → observation for a child in that cohort is tagged to it.
- ☐ Photo on that entry inherits block context via `entity_kind='entry'` — no
  second source of truth, no column on `attachments`.
- ☐ Boundary: `t == start` → live; `t == end` → not live (half-open).
- ☐ Tagged block's `group_id` matches the entry's `group_id`.
- ☐ Skipped/cancelled/break/closed block spanning now → **not** auto-tagged.
- ☐ Overlap → deterministic pick (most-recently-started) + visible ambiguity
  signal; no concurrent block invisible in the picker.

**Speed**
- ☐ Live block present → correct tag with **zero** extra taps over the save.
- ☐ Override to the right block ≤ 2 taps.
- ☐ Tag write adds **zero** awaited network calls and < 16 ms to the save
  handler (same local transaction as the entry).

**Forgiveness**
- ☐ Wrong tag → re-tag ≤ 2 taps; observation, body, photos fully retained.
- ☐ Clearing a tag → `null`, content intact; never deletes/detaches.
- ☐ Re-tag optimistic + reversible offline; survives app-kill before sync.

**Trust**
- ☐ Tagged block shown by resolved title (never a bare UUID); auto-tag visible
  **before** navigating away.
- ☐ Untagged shown explicitly ("No block"), distinguishable from loading.
- ☐ Block→entries reads back: every entry with that `schedule_block_id`
  appears in the block's moment sheet.

**Offline + edge**
- ☐ Fully offline + block live → resolved from local Drift, tagged locally, no
  network.
- ☐ Offline tag + later re-tag both sync; UUID never reassigned.
- ☐ No-block / after-wrap-up → saved with `null`, unblocked, no fabricated tag.
- ☐ Retroactive → picker offers all of today's blocks; not hard-locked to now.
- ☐ Clock crosses a boundary while the form is open → tag resolves at **save
  commit** (or menu-open snapshot on the hero path), not stale at form-open.
- ☐ Block cancelled/deleted after an entry was tagged → entry keeps its tag,
  renders gracefully ("block no longer scheduled"), timeline doesn't crash.

---

## 4. What else this unlocks

All on the *same* column + provider.

1. **Live curriculum/materials** surfaced when a block goes live — cheapest
   win, **needs only `liveBlockProvider`, zero new columns** (block already
   carries `curriculumSessionSlug` + `activityId`).
2. **Auto block recap** — "During Outdoor Play: 6 photos, 2 notes, Maya's first
   time on the bars." `GROUP BY` on `entriesForBlockProvider(blockId)`.
3. **Family lens, block-framed** — the family timeline becomes "during Outdoor
   Play, here's what your kid did." (#2→#3 is one feature for two audiences.)
4. **Voice-note-to-the-block** — `kind='block_note'`, subject null, block from
   the live provider.
5. **Start/Stop = actual vs planned time** — `actualStart/End` columns; also a
   correctness upgrade for the live provider.
6. **Cross-day patterns** — `GROUP BY activity_id` across weeks; `recurrenceId`
   compares "the same Tuesday Art slot" over a term — the curation signal the
   deferred showcase has been missing.

`#5` is the only one here touching schema beyond the keystone column.

---

## 5. The build seed

**Single data change:** one nullable `schedule_block_id` on **`Entries`** —
not on `attachments` (photos inherit via `entity_kind='entry'`), not on
`captures` (clean pre-triage; block lands at promote time). Thread through
`EntriesDao.create` (the `Value.absent()`-when-null pattern, mirroring
`groupId`/`subjectId`), `EntryActions.createObservation`,
`CaptureActions.promoteToObservation`. Add `EntriesDao.watchForBlock` +
`entriesForBlockProvider` for the reverse read.

**Smallest first slice that proves the feel — three pieces:**
1. `liveBlockProvider` (per assigned group, status/kind filtered, 30s tick,
   overlap = most-recently-started).
2. The **live strip** above the omnibox bar — chip only, collapses to zero
   when null. (Hold `⊕ N moments` + the moment sheet for slice two.)
3. Auto-stamp `scheduleBlockId` on the **observation form** save from the live
   block, with the **`Saved → {block}` · Change** toast + override sheet.

That's the whole loop — *see it's live → capture → it tied → fix if wrong* —
on one path. If it feels effortless, the photo hero-path, the moment sheet, the
`📷 N` badges, and everything in §4 are mechanical extensions of the same
column.
