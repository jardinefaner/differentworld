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
3. **AI-generated** — for variety at scale, a *brokered* model (never a key
   on the device — Edge Function, per docs/SECRETS.md; no child identifiers
   in the prompt) generates a batch, which is **reviewed/filtered, then
   banked.** Amortizes to ≈ 0 cost per play.
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

**Slice C — brokered AI refill.** `ensureBank` calls an Edge Function to
top up a kind when low; a review/approve step before AI/crowd items serve
to kids.
