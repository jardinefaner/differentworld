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

## The two layers — one world, two content packs

A weekly world is described by **two aligned packs** — the "two layers of skin"
([VISION.md](VISION.md), 2026-06-07), now keyed 1:1 (same `week` / `id` /
`name` / `emoji` / `color`):

- **The lived experience** (`world_blocks.json`, `WorldBlock`) — what the room
  physically becomes for the week: arrival ritual, room dress, soundtrack, the
  spell-words, the wall-question bank, the key moment, the transition out, and
  the week's **five authored days** (title + minute-by-minute focus).
- **The curriculum** (`ten_worlds.json`, `CurriculumWorld`) — the same world's
  featured **verbs**, **activities**, **Watch→Do videos**, and reveal-world
  matching.

`block.week == world.week` for every week, so `seasonPositionProvider` exposes
them as one position. A surface names the world once (from either pack — they
agree) and presents the verbs as "this week's focus."

### ✅ Resolved — ten weekly worlds is the canonical journey

The decision (2026-06-09): a **new world every week** (VISION's kid-side dream),
so `ten_worlds`' ten weekly worlds are canonical and `world_blocks` was
**restructured from 5 fortnight blocks into 10 weekly worlds** to match —
harvesting the FullExperience prototype's day content for the 7 worlds it
covered (Me · Nature · Water · Space · Dreams · Feelings · Us, splitting the two
merged blocks) and authoring three fresh (Stories · Music · Time). Both packs
now align exactly:

| Wk | Days | The world (both packs agree) |
|----|------|------------------------------|
| 1  | 1–5  | 🪞 World of Me |
| 2  | 6–10 | 📚 World of Stories |
| 3  | 11–15| 🌿 World of Nature |
| 4  | 16–20| 🌊 World of Water |
| 5  | 21–25| 🎵 World of Music |
| 6  | 26–30| 🚀 World of Space |
| 7  | 31–35| 💭 World of Dreams |
| 8  | 36–40| ⏳ World of Time |
| 9  | 41–45| 💛 World of Feelings |
| 10 | 46–50| ✨ World of Us |

Each world is **five days** (`blockForDay` → world index `(day−1) ~/ 5 ==
week−1`). The newly-authored worlds (Stories / Music / Time) and the split
environments (Dreams / Us) are solid first drafts grounded in `ten_worlds`'
taglines / questions / activities — the user's to refine. Transform script:
`tool/restructure_world_blocks.py`.

---

## The five zoom levels (the whole system, one row each)

| Zoom | Span | Content pack | Cast surface | The human's job |
|---|---|---|---|---|
| **Minute** | the daily loop | [THE_DAY.md](THE_DAY.md) | — | room teaches; app touches the day 4× (~12 min) |
| **Day** | one day | `world_blocks` focus + `thinking_games` | `/play-today` | advance the run; mood · picks · activity · messages |
| **Week** | one weekly world (5 days) | both packs (environment + days + verbs + activities) | `/this-week` · the day list | dress the room day 1, flip it day 5; run the verbs |
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

**Whole (end-to-end):** the season clock · **one canonical journey** (both packs
aligned 1:1, 10 weekly worlds) · the day on rails (`/play-today`) · the weekly
world with room prep · wall-question-of-the-day · the print decks · kid +
teacher verb picks · the growth arc · the **season hub** (`/program`) · all cast
surfaces. *A director sets one date and the program runs.*

**Partial:** the **staff layer** (`staff_runbook` + ladder exist; per-day
choreography thin) · the **family season view** (today works; the whole-arc
parent view is light) · the **character sheet as "the player"** (avatar-as-
drawing, age=dailies — seeded, not built) · the **kid-facing footprint** (the
new `/action-words/pick` is in tension with THE_DAY's "zero kid-facing" — it's
an *opt-in alternative* to the physical cards, not the default; decide which).

**Missing:** the per-day **academic binder pages** (THE_DAY's "Day 14: write I
like ___" — the writing/ABC/drawing drills aren't bundled; `world_blocks` has
the *focus*, not the full page) · the **Summer Book** render for the whole 50
days (dream #1's year-end keepsake) · **refinement of the three newly-authored
worlds** (Stories / Music / Time are solid first drafts; the user's to polish).

---

## The acceptance contract — at the season footprint

Every season-level surface is measured against:

1. **One date, zero re-config.** Nothing should ask the director to set up a
   day that the start date already implies.
2. **One canonical "where are we."** No two surfaces name the current world
   differently — satisfied now that both packs align 1:1 and
   `seasonPositionProvider` is the single source.
3. **The day feeds the book.** Every touch a child's day takes must accrete
   into their record — or it's a ledger entry, not a story.
4. **Survives a substitute.** A human who walks in on Day 27 can open the app
   and know the world, the day's focus, the wall question, and each child's
   arc — without a handoff.

*Same engine, ten weeks. One date in; fifty days of becoming out; a book home
with every child. That's the program.*
