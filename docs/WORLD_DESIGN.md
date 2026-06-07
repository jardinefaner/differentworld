# Different World — design

The bridge from **[docs/WORLD.md](WORLD.md)** (the *why* + the *what*) to code
(the *how*). WORLD.md is the vision; this is the buildable spec: the data model,
the screens, how each world-field maps onto systems that already exist, and the
ordered slices to ship it.

**North star (from WORLD.md):** for the whole summer, it is a Different World.
Each child has a persistent in-world *self* (a drawn avatar, a chosen name, an
age that = dailies completed, collected words + earned skills); the program
visits a **new themed world every week** (the 8 packs), where the child joins a
**crew** and chases a **dream**.

---

## Principle: lean on what exists, add a thin layer

The engine already has the bones. The job is mostly a **re-skin + a thin
identity layer**, not a new app. Map first, build second:

| World concept | Existing system to reuse | New?  |
|---|---|---|
| The child | `subjects` | — |
| The drawn self / avatar | `subjects.avatar_url` + `person-photos` Storage | — |
| People (world roles) | the role deck (#8) | re-skin |
| Things (supplies) | the supplies system (#15) | re-skin |
| Words (action words) | action-words (#9) / `entries` | re-skin |
| Dream (the quest) | missions (#16) + `entries` evidence | re-skin |
| Crew | `groups` + `members` | thin layer |
| The week's world | space-level schedule | **new** |
| The character sheet | — | **new (1:1 subject)** |

So the genuinely-new tables are small: a **character sheet** (the persistent
self), a **world schedule** (which world this week), and a **crew identity**
(a name/emblem per group × world). Everything else is reuse.

> **Run `Agent blast-radius` before adding any of these tables.** Each one is
> the 6-place synced-table checklist (CLAUDE.md §3) + RLS + sync rule + a
> PowerSync dashboard deploy. A kid-launchable screen is also the 4 discovery
> surfaces (router / omnibox / nav / settings) + kid-mode hardening.

---

## Data model

### `subjects` (exists) — the child
Unchanged. The character sheet hangs off it 1:1.

### `character_sheets` (NEW, 1:1 with subject) — the persistent self
The summer-long identity. One row per enrolled child; survives every weekly
world reset.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | client-gen |
| `space_id` | uuid | RLS gate (every synced table) |
| `subject_id` | uuid | FK subjects, UNIQUE (1:1) |
| `chosen_name` | text | the world-self's name (kid-authored) |
| `avatar_url` | text | the self-drawing — bucket path, like a photo |
| `born_on` | text (date) | "birthday" = enrollment / first daily |
| `culture` | text | the kid's take, absorbed from the world |
| `capabilities` | jsonb | per-sheet flags, future |

- **Age is DERIVED, not stored** — `age = count(distinct daily-completed days)`.
  No column; computed from missions/entries. (No-punishment vow: total, never
  streaks.)
- **Avatar reuses the photo path** — the drawing is rasterized → uploaded to the
  `person-photos` bucket → the path lands in `avatar_url`, signed on read via
  `signedPersonPhotoUrlProvider`. No new bucket. `PersonAvatar` renders it
  everywhere for free.

### `world_schedule` (NEW, per space) — which world, which week
> ✅ **2026-06-07 — CONFIRMED axis (week → world).** The canonical 10-week
> curriculum ([WORLD.md](WORLD.md) + `curriculum/ten_worlds_prototype.jsx`)
> confirms this is a weekly **journey** (Me → Stories → … → Us). This table
> is the right shape; add an optional per-room override on top if rooms run
> different weeks. The worlds catalog grows from 6 (current, wrong) to the
> canonical **10**, each with **10 facets** + featured verbs + activities.

Drives "this week's world." Worlds themselves are a **code catalog** (below),
so this table just points at one by id per week.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `space_id` | uuid | RLS gate |
| `world_id` | text | catalog key (`high_seas`, `deep_space`, …) |
| `week_start` | text (date) | the Monday this world opens |
| `phase` | text | `arrive` / `live` / `depart` (the week arc) |

### `crews` (NEW) — a team identity per (group × world)
A crew = an existing `group` wearing a world identity for the week. Configurable
(group-default / splittable / kid-formed per WORLD.md §C) — v1 ships
group-default.

| Column | Type | Notes |
|---|---|---|
| `id` | uuid | |
| `space_id` | uuid | RLS gate |
| `group_id` | uuid | FK groups — the real cohort |
| `world_id` | text | catalog key |
| `name` | text | the crew's world name ("The Tide Riders") |
| `emblem` | text | an icon/emoji key |
| `dream_mission_id` | uuid? | the crew's shared dream → a mission row |

### Worlds = a CODE catalog (not a table, v1)
The 8 packs (WORLD.md §B) ship as a Dart catalog — same pattern as role decks /
games / activity templates. Each entry:

```dart
WorldPack(
  id: 'high_seas', title: 'High Seas', emoji: '🏴‍☠️',
  people: ['Captain','Navigator','Lookout','Quartermaster'],
  things: ['compass','treasure map','spyglass',"ship's wheel",'chest'],
  words:  ['ahoy','horizon','treasure','brave','crew','chart'],
  dream:  'find the buried treasure',
  culture:'no one sails alone — crew loyalty, courage, share the bounty',
  palette: WorldPalette(...), // ties LivingBackground from Speak
)
```

Director-custom worlds → a `worlds` table later; v1 is the fixed 8 + bench.

### Dreams + collected words/skills = reuse, don't add tables (v1)
- **Dream** = a `mission` (#16) at world / crew / kid scope; evidence = `entries`
  / attachments. The `crews.dream_mission_id` link is the crew dream; a kid
  dream is a per-subject mission. *Resolved at Departure* = mission complete.
- **Collected words / earned skills** = `entries` with a `kind` (`'word'` /
  `'skill'`), keyed on subject. The "me" screen reads them back. Only promote to
  a dedicated `kid_collectibles` table if the entries query strains.

---

## Screens

Two age surfaces (WORLD.md §F), **same data**, gated on the subject's age band
(afterschool 4–12 → soft for 4–6, full world for 7–12).

### 1. Draw Yourself  *(kid-mode)* — the day-one ritual, the FIRST slice
A finger-drawing canvas: a few fat colors, clear, undo, done. On *done*:
rasterize (RepaintBoundary → `toImage`, the poster pattern) → upload to
`person-photos` → set the subject's `avatar_url`. "This is your face in the
world." No new tables — pure UI + the existing avatar path.

### 2. Me / Character sheet  *(kid + staff + family views)*
The self: drawn avatar, chosen name, age (= dailies), culture, collected words,
earned skills, current crew + world. **Soft surface (4–6):** big avatar, name,
a few words, lots of voiceover. **Full surface (7–12):** the whole sheet, map
location, roles, abilities.

### 3. This Week's World  *(kid + staff)*
The active `world_schedule` pack: its people (roles), things (supplies), words,
the world + crew dream, the culture line. The Arrive → live → Depart arc. Uses
the world's palette via the Speak `LivingBackground`.

---

## Field → system map (the contract)

| WORLD.md field | Reads from | Authored by (default) | Surface |
|---|---|---|---|
| avatar | `character_sheets.avatar_url` | kid (drawn) | Draw Yourself → Me |
| name | `character_sheets.chosen_name` | kid | Me |
| age | derived: dailies count | system (no-punishment) | Me |
| culture | `character_sheets.culture` | world (kid's take) | Me / World |
| people | role deck (#8) per world | director menu | World |
| things | supplies (#15) per world | director menu | World |
| words | action-words (#9) → `entries` | collected by kid | Me / World |
| dream | missions (#16) | world/crew=director, kid=kid | World / Me |
| crew | `crews` over `groups` | director (vote opt-in) | World / Me |
| skills | `entries` kind=`skill` | earned | Me |

---

## Build slices (ordered)

Each slice is independently shippable and leaves the app whole.

1. **Draw Yourself → avatar.** *(no new tables)* Drawing canvas → rasterize →
   `person-photos` upload → set `subjects.avatar_url`. Route + a staff entry
   ("Have {child} draw themselves") behind kid-mode. **← the first slice.**
2. **Character sheet shell.** `character_sheets` table (the 6-place checklist) +
   a read-only "Me" screen (avatar + name). Chosen-name edit.
3. **Worlds catalog (code) + `world_schedule`** + a "This Week's World" surface
   (read-only: the pack's people/things/words/dream/culture + palette).
4. **Crews.** `crews` table over `groups`; crew name/emblem per world.
5. **Dreams = missions.** Wire world / crew / kid dreams onto missions +
   resolve-at-Departure; evidence via entries/attachments.
6. **Collected words + skills** on the Me screen (entries read-back); age =
   dailies wired.
7. **The two age surfaces** (soft 4–6 / full 7–12) + voiceover for pre-readers.
8. **Rituals** — day-one (draw + name) + week-one (reveal / crew / dream) flows
   stitched; Departure ceremony; the first/final self-portrait bookend.

---

## Privacy (the vow — WORLD.md §J)

- **No real location, ever.** Any "map" is the *fictional* world's geography.
  No real coordinates stored.
- **The pseudonymous drawn self is the privacy WIN** — a chosen name + a drawing
  inside a made-up world is far less PII than a photo + legal name. Lean in.
- **Storage like photos** — the avatar drawing lives in the space-scoped
  `person-photos` bucket (RLS = space membership), signed URLs, never public.
- **Kid-mode hardening** — every kid-launchable surface needs a staff-only exit
  (the survey-take 5-tap + PIN pattern) and route-pop hardening so system-back
  can't break the kid out. (WORLD.md "Ava — kid-mode" deferred items.)

---

## Status

- **Vision:** fully shaped — [docs/WORLD.md](WORLD.md) (A–K settled).
- **Design:** this doc — data model + screens + mapping + slices.
- **Build:** slice 1 (Draw Yourself) in progress on `feat/different-world`.
- This is a **multi-session feature**; WORLD.md + this doc are the durable baton.
