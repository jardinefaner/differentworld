# Action Words — the world-reveal system

> Kids pick **3 action words** each morning, do activities that match, and at
> the end of the day **discover** which animal/element their combination
> reveals. The app touches the kid for ~5 minutes a day (morning pick, evening
> reveal); everything between is physical, human, in the room. **The room is
> the product. The app gets out of the way.**

This is the developer brief (2026-06-06), distilled. [VISION.md](VISION.md) is
the *why*; this is the *what + how it maps to the engine*.

## The loop

1. **CHOOSE** — kid taps 3 of 12 verb cards. That's their day.
2. **DO** — teacher runs matched activities physically. No screens.
3. **DISCOVER** — end of day, the app reveals which **world** the 3-verb combo
   maps to. The kid didn't know. Now they do. That's the reward.
4. **COLLECT** — the world joins their collection; a **title** forms from their
   most-practiced verbs over time.

## The 12 verbs (permanent — never change)

`CARRY 📦` `LISTEN 👂` `PLAY 🎉` `SPARK ✨` `FLOW 🌊` `BUILD 🧱`
`WATCH 👀` `WAIT ⏳` `SOLVE 🧩` `HELP 💛` `ECHO 🔁` `SHINE 💡`

Canonical source: `lib/features/action_words/verbs.dart`. IDs are lowercase
(`carry`, `listen`, …).

## The worlds (verb-combo → world)

C(12,3) = **220** unordered 3-verb combos. ~40 map to **named worlds**
(animal/element/archetype); the rest resolve to the **closest** named world
(≥2 shared verbs) or a **"new world — you name it"** moment.

Starter named set (from the brief; extend in `worlds.dart`):

| Verbs | World | Title |
|---|---|---|
| carry + help + listen | 🐜 Ant | The Servant Leader |
| play + echo + flow | 🐬 Dolphin | The Joyful Connector |
| watch + spark + shine | 🦅 Eagle | The Visionary |
| listen + wait + watch | 🦉 Owl | The Wise Observer |
| build + solve + spark | 🐝 Bee | The Maker |
| flow + help + shine | 💧 Water | The Nurturer |
| spark + shine + play | 🔥 Fire | The Energizer |
| shine + wait + help | ⭐ Star | The Steady Light |

Canonical source + lookup: `lib/features/action_words/worlds.dart`
(`matchWorld(Set<String> picks)`). Order-independent (picks are normalized to a
sorted key). **TODO: the user owns the remaining ~32 named worlds — append
them to `kNamedWorlds`.** A few obvious extras are seeded + marked so the
collection isn't empty; replace freely.

## The two halves — doing *clears*, growth *accumulates*

A load-bearing design principle (the user's, 2026-06-06):

- **Doing is ephemeral — it clears to zero.** The day's tasks are **big
  image-buttons, not lists**. Each one **hides when done**, so the surface
  *drains toward "tasks zero"* — a clean, satisfying, finished room. Tasks
  are **sourced from missions + roles** (the existing systems are the
  catalog of "jobs the room does"). The win is the *emptying*, not a
  checklist of strikethroughs.
- **Growth is permanent — it stays *unhidden*.** Worlds, the collection,
  the emerging title, the words/spells a class learns, the culture they
  build — these **accumulate and stay visible**. The collection grid, the
  "Becoming…" title, the spell vocabulary: growth is the thing you *don't*
  hide.

So: the **Do board** (missions/roles as big buttons → zero) and the
**Collection/culture** (worlds/words/title, ever-visible) are the two poles
of the loop. Build the doing to *disappear*; build the growth to *remain*.

## Spells are words in other languages

The spell commands (FREEZE / CREATE / SHARE / MOVE / WONDER) are not just
English timer words — each is (or carries) a **word in another language**.
The fullscreen spell is a tiny culture/language moment: the foreign word +
its meaning + the timer. Over a term the class learns a vocabulary of
spells across languages — part of the *growth that stays unhidden*.

## They create their own worlds, words, culture — with continuity

The system is **generative, not just a fixed catalog**. Kids and programs
**author their own**:

- **worlds** — the *fresh world → you name it* moment (shipped) is the seed;
  a class can name and keep worlds the lookup never had.
- **words** — their own spells / vocabulary / verbs-in-their-languages.
- **culture** — a shared, program-specific language + set of worlds that
  grows over a term and **carries forward (continuity)** year to year.

The fixed 12 verbs + ~40 worlds are the *starter* substrate; the real
product is what each room *builds on top* and keeps. Growth unhidden.

## Data model — maps onto the existing engine

The engine is already domain-agnostic (Space / Member / Group / Subject /
entries). Action Words adds **mechanic + content**, not new core tables.

| Brief concept | Engine |
|---|---|
| Program | `spaces` (rooms = `groups`; currentWeek/theme = schedule/space caps) |
| Kid | `subjects` (name + verb data; **no photos**, per the brief) |
| Day (per kid per date) | **`entries.kind='action_words'`** — one row per (subject, date). `details` = `{verb_picks:[3], done:[…], note, word_of_day, world_name?}`. Reuses the synced table — **zero new table.** |
| Collection (per kid) | **derived** from all the kid's `action_words` entries — world counts + verb totals + emerging title. No table. |
| Activity | the existing **activities** feature, **+ 3 verb tags + instruction + type + ages + printable file** (a later wave tags the library). |
| Spell | timers (FREEZE/CREATE/SHARE/MOVE/WONDER) — a small fullscreen-countdown surface (reuses the immersive provider). |

`world` is **derived** from `verb_picks` via `matchWorld` (deterministic), so
the "reveal" is a UI moment, not stored state — except a kid-named **new
world**, whose chosen name lands in `details.world_name`.

## Users

- **Teacher (Conductor)** — primary. One thumb, ≤60s at a time. Screens: Today
  (clock-aware block + kid cards w/ verb dots + quick note + word-of-day),
  Verbs (morning pick), Activities (matched library), Spells (timers), Send
  (auto parent message + copy).
- **Kid (Explorer)** — optional V1. Emoji-only (ages 4–7 can't read): verb grid,
  3 habit cards w/ filling dots, the glowing reveal, the collection grid.
- **Parent (Witness)** — V1 is **not an app**; it's the copy-pasteable text the
  teacher's Send screen generates.

## The feel

Calm, dark, minimal — "a quiet room with one candle." Dark backgrounds, soft
gold accents, serif for warmth, mono for data. Subtle animation (dots filling,
emoji glow, fade-in). **The spell screen is the only loud moment** (fullscreen
emoji, breathing, countdown). Don't build an app that wants attention.

## What NOT to build

No chat / social. No points/levels/badges/leaderboards (collection grid only).
No AI in V1 (the reveal is a lookup, not ML). No kid photos / PII beyond name +
verb data. No heavy onboarding (add kids by name = setup).

## Build roadmap (V1 order)

1. ✅ **Foundation** — verbs catalog + worlds lookup + `action_words` entry kind
   + providers/actions (`action_words_providers.dart`). *This wave.*
2. **Verb pick** — tap kid → tap 3 verbs → teacher sees the matched world.
3. **Activity matcher** — show library activities matching the picked verbs.
4. **Today dashboard** — kids as cards: verb dots + quick notes + word-of-day.
5. **World reveal** — the glow moment (shared component; teacher + kid).
6. **Spell timers** — fullscreen countdown.
7. **Parent message generator** — auto-text + copy button.
8. **Collection tracking** — worlds + verb counts + emerging title over time.
9. **Activity library** — browse/filter/search + add custom + attach files.

## Status

- **Foundation + the choose→discover magic** is the first build target. Kid
  screens are optional for V1 — the **teacher** is the primary user, so teacher
  surfaces lead. Activity-library verb-tagging, spells, parent message, and
  collection are sequenced waves after the core loop is demoable.
