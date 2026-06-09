# THE PROGRAM — one season, ten weeks

The zoom-level **above** [THE_DAY.md](THE_DAY.md). Where THE_DAY is the day's
acceptance contract ("would this survive in that day, at that footprint?"),
this is the **season's**: how a single 10-week / 50-day program is set up,
unfolds, and leaves each child a book. The synthesis of everything built so
far (2026-06-08).

> The day does the teaching. The season does the becoming. Set one date and
> the program runs itself; the app's job is to always know **where we are** and
> **who each child is turning into.**

---

## The spine — one date unfolds the whole season

Everything keys off a **single value**: `program_start_date` (a Space
capability, set once on `/this-week` → Manage journey). That one date drives
two provider chains, with no per-day configuration ever:

```
program_start_date
  ├─ currentCurriculumWeek (1–10) ─ currentWorld    ten_worlds.json
  │                                                  (verbs · facets · activities · Watch→Do)
  └─ currentProgramDay    (1–50) ─ currentBlock     world_blocks.json
                                  ├ todaysJourneyDay  (the day's title + focus)
                                  └ todaysWallQuestion
```

Source: `world_schedule.dart` (`programDayFor` reuses `curriculumWeekFor`) +
`world_blocks.dart`. Set the date → the app always knows this week's world,
today's day-of-50, the wall question, the room setup. **This is the engine.**

---

## The two layers — the immersive world vs the week's focus

The program is themed **twice at once** — the "two layers of skin"
([VISION.md](VISION.md), 2026-06-07):

- **The immersive WORLD** (`world_blocks.json`) — a **2-week** setting the room
  physically becomes: arrival ritual, room dress, soundtrack, a key moment, the
  transition out. *Where the child is living.* Five of them across the summer:
  🪞 Me · 🌿 Nature · 🌊 Water · 🚀 Space+Dreams · 💛 Feelings+Us.
- **The week's FOCUS** (`ten_worlds.json`) — a **1-week** curriculum lens: the
  featured verbs, the activities, the Watch→Do videos, the reveal-world
  matching. *What the child is working on.* Ten of them: Me · Stories · Nature ·
  Water · Music · Space · Dreams · Time · Feelings · Us.

These are **different roles**, not competitors — so a surface should never show
*both* as "World of X." The block is the **world** (the noun); the week is the
**focus** (the work). Lead with the day number (unambiguous), name the block as
the world, and present the week only as its verbs/activities.

### ⚠️ Open decision — the two packs are different journeys

The five immersive worlds and the ten weekly foci do **not** thematically nest
(authored at different times — `ten_worlds` from `docs/curriculum/`,
`world_blocks` ingested 2026-06-08 from the FullExperience prototype):

| Wk | Days | Immersive world (block) | Week focus (ten_worlds) | Coherent? |
|----|------|-------------------------|--------------------------|-----------|
| 1  | 1–5  | 🪞 World of Me          | Me                       | ✅ |
| 2  | 6–10 | 🪞 World of Me          | Stories                  | ~ |
| 3  | 11–15| 🌿 World of Nature      | Nature                   | ✅ |
| 4  | 16–20| 🌿 World of Nature      | Water                    | ~ |
| 5  | 21–25| 🌊 World of Water       | **Music**                | ❌ |
| 6  | 26–30| 🌊 World of Water       | **Space**                | ❌ |
| 7  | 31–35| 🚀 Space + Dreams       | Dreams                   | ~ |
| 8  | 36–40| 🚀 Space + Dreams       | **Time**                 | ❌ |
| 9  | 41–45| 💛 Feelings + Us        | Feelings                 | ✅ |
| 10 | 46–50| 💛 Feelings + Us        | Us                       | ~ |

Weeks 5–6 are the tell: a *Music* and *Space* curriculum inside a *Water*
world doesn't read. **A coherent program needs one canonical journey.** The
recommendation (un-acted, awaiting the call): make **`world_blocks` canonical**
(it's the richer, newer design — it carries the actual daily substance:
environment, the day's focus, the wall-question bank), and re-key
`ten_worlds`' verb/activity/video content to the 5-world structure so the week
focus always sits inside its world. Until then, surfaces lead with the **block
+ day number** and treat the week only as a verb/activity list — never a second
world title.

---

## The six zoom levels (the whole system, one row each)

| Zoom | Span | Content pack | Cast surface | The human's job |
|---|---|---|---|---|
| **Minute** | the daily loop | [THE_DAY.md](THE_DAY.md) | — | room teaches; app touches the day 4× (~12 min) |
| **Day** | one day | `world_blocks` focus + `thinking_games` | `/play-today` | advance the run; mood · picks · activity · messages |
| **Fortnight** | a block (10 days) | `world_blocks` (arrival→transition) | `/this-week` fortnight list | dress the room day 1, flip it day 10 |
| **Week** | a curriculum world | `ten_worlds` (verbs · activities · videos) | `/this-week` | run the week's verbs + activities |
| **Season** | 10 weeks / 50 days | both packs, in order | `/journey` · the season hub | orient staff/families; season opener |
| **Child** | the whole arc, per kid | their `action_words` entries | `/growth/:id` · book · sheet | cast their story at closing / pickup |

Each level = a **content pack** (authored once, offline) × a **cast surface**
(the present spine) × **one clear human job**. The 12 verbs are the through-
line: a kid's pick is their *identity* (character sheet), their *job* for the
day (Mover/Navigator…), and a *staff skill* (`verb_roles`).

---

## The per-child thread — the day produces the keepsake

A child's `action_words` entries accrete across the 50 days:

```
each day: 3 verb picks ─ a revealed world ─ collection grows ─ emerging title ─ growth arc ─ the book
```

`actionWordsCollectionProvider` already derives the worlds collected, the
verb totals, and the emerging title ("The Owl Who Listens") from every day's
entry. `/growth/:id` casts it as a story. This thread is the answer to "what
are we even doing": not entertaining, not testing — **giving a kid a world to
become someone in, and proof of who they became** (VISION dream #1 + the
2026-06-06 "the player" reframe).

---

## The four app-touches that hold the whole season

Per THE_DAY's footprint, the app touches each day **four times**; over 50 days
that's the entire data spine:

| Touch | Per day | Accretes into |
|---|---|---|
| Mood | 5 sec | the child's weather log |
| Verb picks | 10 sec/kid (or kid self-picks `/action-words/pick/:id`) | their worlds + emerging title |
| Activity match | 15 sec | what the room actually did |
| Parent message | 10 min after pickup | the family's daily thread |

Closing reveal (1 tap) is the fifth, optional, emotional-peak touch.

---

## So far — whole / partial / missing for a full 10-week run

**Whole (end-to-end):** the season clock · the day on rails (`/play-today`) ·
the fortnight with room prep · wall-question-of-the-day · the print decks ·
kid + teacher verb picks · the growth arc · all cast surfaces. *A director sets
one date and the program runs.*

**Partial:** the **staff layer** (`staff_runbook` + ladder exist; per-day
choreography thin) · the **family season view** (today works; the whole-arc
parent view is light) · the **character sheet as "the player"** (avatar-as-
drawing, age=dailies — seeded, not built) · the **kid-facing footprint** (the
new `/action-words/pick` is in tension with THE_DAY's "zero kid-facing" — it's
an *opt-in alternative* to the physical cards, not the default; decide which).

**Missing:** **the one canonical journey** (the two packs above) · the
per-day **academic binder pages** (THE_DAY's "Day 14: write I like ___" — the
writing/ABC/drawing drills aren't bundled; `world_blocks` has the *focus*, not
the full page) · the **Summer Book** render for the whole 50 days (dream #1's
year-end keepsake) · a **season hub** (the in-app counterpart to this doc —
where-we-are + this-week + today + the arc + each child; *being built*).

---

## The acceptance contract — at the season footprint

Every season-level surface is measured against:

1. **One date, zero re-config.** Nothing should ask the director to set up a
   day that the start date already implies.
2. **One canonical "where are we."** No two surfaces name the current world
   differently (the seam above is the standing violation).
3. **The day feeds the book.** Every touch a child's day takes must accrete
   into their record — or it's a ledger entry, not a story.
4. **Survives a substitute.** A human who walks in on Day 27 can open the app
   and know the world, the day's focus, the wall question, and each child's
   arc — without a handoff.

*Same engine, ten weeks. One date in; fifty days of becoming out; a book home
with every child. That's the program.*
