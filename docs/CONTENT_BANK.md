# The content bank — generate once, reuse forever

**Status:** design approved (2026-05-31). Local seed implementation
building now; the DB + AI-refill backing is the scaling wave.
**Origin:** "like math, we generate unique answers and we save those in our
database so we don't have to keep asking AI to generate."

**The one principle:** activity content (this-or-that pairs, word-game
categories, interview questions, seed word pairs…) is **made once and
banked**, then served from the bank forever. AI is called to *fill* the
bank, never on the hot path of a play. Local generation (math) needs no
bank at all — it's infinite and free.

---

## 1. Where content comes from (cheapest first)

1. **Local / procedural** — math inverse expressions, "starts-with-C"
   letter checks. Pure Dart, infinite, free, offline. **No bank needed.**
2. **Curated** — a human-written seed list (this-or-that pairs, categories,
   interview-question starters). Kid-safe by construction; ships in the
   app. The first fill of the bank.
3. **AI-authored, committed (the global library)** — for variety at scale,
   content is generated **through Claude Code at dev time** and committed as
   a seed migration into `content_items` as GLOBAL rows (`space_id IS NULL`,
   `source = 'ai'`), shared across every program via the `global_content`
   sync stream. The kid-safety review is the **commit review** (the batch is
   readable SQL in the PR — you see exactly what ships), so there is no
   runtime model call, no vendor key on the device or server, and no
   per-play cost. **The table is a living document**: each session can add
   another seed migration to grow it. (We chose this over a runtime brokered
   Edge Function — same end state, far less surface area and zero ongoing
   cost. A runtime generator can still be added later if scale demands it.)
4. **Crowd-grown** — the kids' own creations feed the bank: the clever
   "paths to 12", the funny this-or-that pairs they invent, the novel
   "C animals" they find. Play makes the bank richer.

The bank de-dupes across all four so every item is unique.

---

## 2. The model (one noun table)

A content item is a SEMANTIC_GRAPH noun — data, generated once, synced,
reused:

```
content_items {
  id            uuid pk
  space_id      uuid null    -- null = shared/global; set = this program's
  kind          text         -- 'this_or_that' | 'category' | 'interview_q' …
  payload       jsonb        -- {optionA, optionB} | {category} | {question} …
  fingerprint   text         -- de-dupe hash of the normalized payload
  source        text         -- 'curated' | 'ai' | 'crowd' | 'local'
  created_by    uuid null
  created_at    timestamptz
  unique (kind, space_id, fingerprint)   -- uniqueness is enforced here
}
```

- **Seen-tracking** so a kid/cohort doesn't repeat: a light `content_seen
  { subject_id|group_id, content_id }`, or the seen-ids ride the activity
  run's entry. Serve unseen first; when a kind runs low, refill.
- **Refill service** — `ensureBank(kind, n)`: if the unseen count for a
  kind drops below a threshold, generate/curate `n` more (brokered AI or a
  seed top-up), de-dupe by fingerprint, insert. Runs off the hot path.

This is the standard six-place synced table (migration + publication +
sync rule + PowerSync schema + Drift + DAO) plus the refill service.

---

## 3. The interface (so local now, DB later, same shape)

Activities never know where content comes from — they ask a bank:

```dart
abstract class ContentSource {
  ContentItem? next(String kind);     // next unseen, or null when dry
  List<ContentItem> take(String kind, int n);
  int remaining(String kind);
}
```

- **Now:** `LocalContentBank` — curated seed lists in Dart, in-session
  seen-tracking. Zero backend; proves the "made once, reused, no repeats"
  feel immediately.
- **Later:** `DriftContentBank` — the same interface backed by
  `content_items` + `content_seen`, with `ensureBank` refilling via the
  brokered AI. Activities don't change.

---

## 4. The rules

- **Never call AI on the hot path.** A play reads the bank; the bank is
  filled ahead of time / lazily, never during the tap-to-next.
- **Prefer local generation.** If content can be procedural (math, letter
  checks), it doesn't go in the bank at all.
- **Brokered AI only, no PII.** Cloud generation goes through an Edge
  Function; the master key never reaches the device; prompts carry no
  child identifiers.
- **Kid-safety gate on AI/crowd content.** AI- and crowd-sourced items are
  reviewable/filterable before they're served to kids (a `source` flag +
  an approve step for the AI/crowd tiers).
- **Uniqueness at the bank, not the activity.** The `fingerprint` unique
  constraint is the single guard; activities just ask for "next unseen".

---

## 5. The build seed

**Slice A — `LocalContentBank` (now).** The `ContentItem` + `ContentSource`
types, a `LocalContentBank` with curated seeds, in-session seen-tracking.
This-or-That and the word game consume it. Proves the pattern with no
backend.

**Slice B — the DB bank.** `content_items` (+ optional `content_seen`) as a
synced table; `DriftContentBank` behind the same `ContentSource`; the
crowd-grow path (kids' creations insert deduped).

**Slice C — the global library, authored through Claude Code.** Content is
generated at dev time and committed as seed migrations into `content_items`
(global rows, `source='ai'`), grown over time as a living document. The
kid-safety gate is the commit review. No runtime model, no vendor key, no
per-play cost. (Superseded the original "brokered AI Edge Function" plan —
see §1.3.)
