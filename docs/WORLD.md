# Different World — the kid-facing world(s) (vision-shaping checklist)

Home for the 2026-06-06 reframe in [VISION.md](VISION.md). **Not a design doc
yet** — the shape of the dream + a checklist of what to SHAPE before we design.
Mark `[x]` settled, `[ ]` open, `💭` an idea to chew on.

## ⚠️ 2026-06-07 correction — worlds are the ROOMS, not a weekly rotation

The user corrected the "new world each week" model below. The truth:

- **The worlds are the program's standing rooms.** A summer program runs a
  fixed set of **5 rooms**, and each room IS a world. Kids move *between
  rooms*; a world is a *place that persists*, not a week that passes. (The
  "journey through a new world each week" framing below is superseded — keep
  it for history, but the rooms are the unit.)
- **The world set (umbrella "Different World"):** **World of Books · Movies ·
  Songs · Dreams · Space · Time** — "fun things for a 10-week summer
  program." (Code catalog: `lib/features/action_words/themed_worlds.dart`.)
- **What's in a world ("if they were to create a different world, what's in
  this?"):** **People · Culture · Map (pretend locations) · Tools · Dreams.**
  This refines the People/Things/Words/Dreams/Culture list below — it ADDS a
  **Map** (invented geography only — never a child's real location) and names
  **Tools** (≈ things). *Words* stays its own system (Action Words). The room
  + kids BUILD these facets for their world (the buildable canvas is a
  follow-up; v1 ships the facet scaffold as prompts — `kWorldFacets`).
- **Implication for the data model:** the planned `world_schedule` (week →
  world) is the wrong axis. The right one is **room → world** (a world id on
  the `group`, since groups = rooms). `crews` (group × world) is closer.
  Revisit `WORLD_DESIGN.md`'s "the week's world" table before building it.

Everything below is the prior (still-useful) thinking; read it through the
lens of the correction above.

## The model: a persistent self, traveling through a new world each week

Two layers:

**1. The weekly world — changes every week.** The summer is a JOURNEY through
many worlds: a new themed world each week — **pirates, then outer space, then
under the sea, …**. Each world is a *place*, and it's POPULATED:
- **People** — who lives here (a pirate captain, an astronaut, a mermaid). The
  role deck (#8), themed.
- **Things** — what's here (a compass, a spacesuit, a shell). Supplies / objects
  (#15), themed.
- **Words** — how they talk here ("ahoy · treasure · horizon" / "orbit ·
  gravity · liftoff"). Action Words (#9), drawn from the world.
- **Dreams** — what there is to chase here (find the treasure, reach the moon,
  map the reef). Quests / goals.
- **Culture** — the vibe + values + rituals of this world.

**2. The persistent self — travels through all of them.** The character sheet
(the 2026-06-06 reframe): your **drawn avatar, chosen name, age (= dailies),
and accumulated words / skills / abilities** is YOU, carried world to world. The
worlds change around you; you keep growing.

And inside each world, you have:
- **A crew** — your team for the week. You don't enter a world alone.
- **A dream** — your (or your crew's) goal / quest in that world.

**The week-shape:** *arrive in a new world → join/form a crew → take up a dream
→ meet its people, use its things + words, live its culture → carry the growth
forward* into next week's world.

This makes **"one engine, many worlds" (#13) literal on the KID side**: each
weekly world is a **themed content pack** — people = roles, things = supplies,
words = action words, dreams = quests, culture = vibe — that the systems we've
already built get *re-skinned* by. New world = new pack, same engine.

## What's new vs what exists
- **NEW**: the weekly-world **cadence + themes**, the per-world **content pack**,
  the **crew** (a team), the **dream** (a per-world quest).
- **EXISTING, re-skinned per world**: roles (#8) = the world's people; supplies
  (#15) = its things; action words (#9) = its words; missions (#16) = how
  dreams get pursued with real evidence; the character sheet = the self that
  travels; the growth book (#1) = where each world's chapter lands.

---

## Decided so far
- [x] **Two surfaces, blended by age** (4–6 soft + playful; 7–12 full world).
  Same data underneath.
- [x] **A persistent self travels through a NEW themed world each week**
  (pirates / space / sea / …). The self carries; the world changes.
- [x] **Each world is a content pack**: people, things, words, dreams, culture.
- [x] **Starter catalog (8 packed worlds)**: High Seas 🏴‍☠️, Deep Space 🚀, Under
  the Sea 🌊, Deep Jungle 🌿, Lost Kingdom 🏺, The Future 🤖, Castle & Quest 🐉,
  Tiny World 🐞. Bench (easy adds): Arctic ❄️, Safari 🦁, Dinosaurs 🦕, The City
  🏙️. **Rule:** a world ships only if it fills all five (people / things / words
  / dream / culture).
- [x] **One world per week**, shaped: **Arrive** (the world is revealed → draw /
  name your self into it → join a crew → take a dream) → **the week** (dailies
  chase the dream; collect the world's words / roles / skills) → **Depart**
  (the dream resolves → a small ceremony → a page lands in the book). ~8–10
  weeks ≈ a summer.
- [x] **Authorship = ALL, layered** (every path a capability): **ship** the
  catalog (the floor, works day one) + director **orders the season arc** +
  director **builds custom** worlds (the ceiling) + optional **kids vote** the
  next world.
- [x] **Continuity = ALL, layered**: the **self always carries** (avatar, age,
  collected words / skills); PLUS an optional **summer-long through-line** (a
  season story) AND a loose **motif** (a passport stamped per world + a
  recurring guide). Composable + director-configurable.
- [x] **Crew = configurable** (classroom group by default · splittable into
  small crews · kid-formed) with an identity re-skinned per world.
- [x] **Dream = nested 3 levels** (world → crew → kid), pursued via dailies /
  missions (#16) — "age = dailies" IS progress toward it — resolved at Departure
  (ceremony + a page in the book).
- [x] **The self accumulates; the world is fresh; collection flows up.** Age /
  words / skills grow all summer + never reset; the crew identity, dream, and
  world reset each week; what you earn in a world joins your permanent self. One
  summer-name; avatar drawn once + optional per-world costumes; re-drawn at the
  end as the bookend.
- [x] **Two surfaces by age** with a per-field language map (full "world" voice
  for 7–12; soft voice for 4–6), same data underneath.

## A. The worlds (the weekly themes) — SETTLED (2026-06-06)
- [x] **Catalog** — the starter 8 + bench (above). Each fills all five pack
  dimensions or it doesn't ship.
- [x] **Cadence** — one world / week, shaped Arrive → week → Depart (above).
- [x] **Arrival + departure** — Arrive: reveal + draw/name into it + join a crew
  + take a dream. Depart: the dream resolves + a ceremony + a book page.
- [x] **Authorship** — layered: ship + director-orders-arc + director-custom +
  kid-vote (all capabilities).
- [x] **Continuity** — layered: self always carries + optional through-line +
  optional passport/guide motif.
- [ ] *Open detail:* the exact per-world pack CONTENTS (see §B) — to flesh out
  world by world once the spine is set.

## B. Inside a world (the content pack) — FLESHED (2026-06-06)
Each dimension maps to a system: **people → roles (#8)**, **things → supplies
(#15)**, **words → action words (#9)**, **dream → missions (#16)**, **culture →
the world's vibe/values**. The 8 starter packs:

### High Seas 🏴‍☠️
- **People:** Captain · Navigator · Lookout · Quartermaster
- **Things:** compass · treasure map · spyglass · ship's wheel · chest
- **Words:** ahoy · horizon · treasure · brave · crew · chart
- **Dream:** find the buried treasure — read the map + the stars, dig it up
- **Culture:** no one sails alone — crew loyalty, courage, share the bounty

### Deep Space 🚀
- **People:** Commander · Pilot · Engineer · Science Officer
- **Things:** rocket · spacesuit · telescope · control panel · rover
- **Words:** orbit · liftoff · gravity · explore · signal · launch
- **Dream:** reach the new planet — build the rocket, plot the course, land
- **Culture:** explorers go together — every job matters, curiosity first

### Under the Sea 🌊
- **People:** Diver · Marine Biologist · Merperson · Sub Pilot
- **Things:** submarine · mask · net · shell · the glow of the deep
- **Words:** dive · current · reef · deep · glow · bubble
- **Dream:** find the lost city — descend, map the reef, follow the glow
- **Culture:** wonder + care for the ocean — leave it better than you found it

### Deep Jungle 🌿
- **People:** Explorer · Ranger · Zoologist · Guide
- **Things:** binoculars · vine · map · backpack · camera
- **Words:** trek · canopy · wild · trail · spot · roar
- **Dream:** find the rare creature — follow the tracks, watch quietly
- **Culture:** respect the wild — observe, don't disturb; patience

### Lost Kingdom 🏺
- **People:** Archaeologist · Explorer · Keeper · Ruler
- **Things:** lantern · scroll · artifact · key · ancient map
- **Words:** ancient · discover · tomb · secret · relic · uncover
- **Dream:** uncover the tomb — decode the scroll, find the key, open the door
- **Culture:** history's mysteries — honor the past, careful discovery

### The Future 🤖
- **People:** Inventor · Engineer · Coder · Designer
- **Things:** gadget · circuit · hologram · robot · blueprint
- **Words:** invent · build · tomorrow · power · design · spark
- **Dream:** build the machine — sketch it, gather the parts, switch it on
- **Culture:** make what doesn't exist yet — try, fail, try again

### Castle & Quest 🐉
- **People:** Knight · Wizard · Royal · Squire
- **Things:** shield · scroll · map · crown · lantern
- **Words:** brave · quest · kingdom · honor · noble · oath
- **Dream:** complete the quest — take the oath, face the trial, return a hero
- **Culture:** courage + honor — protect the small, keep your word

### Tiny World 🐞
- **People:** Bug Explorer · Tiny Scientist · Garden Guide
- **Things:** leaf · dewdrop · petal · blade of grass · tiny map
- **Words:** tiny · crawl · buzz · giant · climb · drop
- **Dream:** cross the garden — climb the stem, cross the puddle, reach the bloom
- **Culture:** big things in small places — courage isn't about size; notice all

- [ ] *Open:* the bench worlds (Arctic / Safari / Dinosaurs / City) get packs
  when promoted; director-custom worlds fill the same five fields.

## C. The crew — SETTLED (2026-06-06)
- [x] **What is a crew** — configurable (ALL, each a capability): default = the
  classroom **group** (reuse `groups`); director can split a group into small
  crews (3–5) per world; or kids form their own (cross-group, with the roster /
  safety caveat).
- [x] **Identity** — a name + emblem, **re-skinned per world** (Tide Riders →
  Star Jumpers). Membership can persist or reshuffle (configurable); the bond is
  the constant, the costume changes.
- [x] **Shared or solo dream** — both (see §D, the nested 3-level dream).

## D. The dream — SETTLED (2026-06-06)
- [x] **Whose** — ALL THREE, **nested**: the **world** has a big shared dream
  (find the treasure / reach the planet); each **crew** has its dream (their
  slice of it); each **kid** has a **personal** dream within. The kid sees
  their own; the crew rallies a shared one; the world frames the epic.
- [x] **How pursued** — via **dailies / missions (#16)** with real-life
  evidence. **"Age = dailies" is literally progress toward the dream** — every
  daily you complete moves it forward.
- [x] **How it resolves** — at **Departure** (week's end): a ceremony + the
  dream's outcome added as a page in the growth book (#1).

## E. The persistent self — SETTLED (2026-06-06)
- [x] **The rule: the self ACCUMULATES; the world is FRESH; collection flows
  UP.** What's yours grows all summer; what's the world's resets each week; what
  you pick up in a world JOINS your permanent self.
- [x] **Avatar** — drawn ONCE (your face for the summer) + optional **per-world
  costumes** (you in pirate garb, in a spacesuit) as a magical extra. Bookend:
  re-draw yourself at the end (age 0 → age N).
- [x] **Age = dailies** — accrues across ALL worlds; never resets, never drops.
- [x] **Words / skills / abilities** — KEPT + collected: each world's earned
  words / skills join your permanent set; you leave the summer with all of them.
- [x] **Name** — one summer-name (your world-self), constant across worlds.

## F. The two surfaces — language map — SETTLED shape (2026-06-06)
Same data, two voices (4–6 may also simply hide the heavier fields):

| field | 7–12 (full world) | 4–6 (soft) |
|---|---|---|
| avatar | "your character" | "the you you drew" |
| name | "your world-name" | "what to call you" |
| age | "Age 9" | "9 days in your world" |
| skills | "Skills" + badges | "things you can do" |
| abilities | "your abilities" | "your power words" |
| crew | "your crew" | "your team" |
| dream | "your quest" | "what you're after" |
| world | "Week 3 · Deep Space" | "this week: SPACE! 🚀" |

- [x] Same data underneath; the surface (words + which fields show) switches by
  age band (or a director toggle).

## G. Progression, the arc & no-punishment — SETTLED (2026-06-06)
- [x] **What grows:** age (= dailies), collected words, earned skills/abilities,
  the avatar (costumes + the final re-draw), crew bonds. The self is *visibly*
  bigger at summer's end.
- [x] **Milestones FEEL like a small ceremony, not a popup** — a dream achieved
  at Departure, an age threshold, a skill mastered: a quiet, room-shareable
  moment (ties the present/control engine #18), never a coin-pop.
- [x] **No-punishment vow (#4/#11):** TOTAL, not streaks. Missing a day never
  removes anything; absence is never penalised; consistency is celebrated.
- [x] **The bookend:** first vs final self-drawing is the keepsake's spine (#1).

## H. Authorship — SETTLED (2026-06-06): per-element, configurable
- [x] **Defaults:** name = **kid**; world + crew = **director** (kid-vote
  optional); culture = absorbed from the **world** (kid takes their angle);
  skills = **earned**; words = **collected**; avatar = **kid** (drawn).
- [x] **Director menus (capabilities):** the world catalog + order, role deck,
  supplies, word bank, skill list — all program-configurable, every default
  overridable.

## I. The social / shared dimension — SETTLED (2026-06-06)
- [x] **Visibility, per element (configurable):** **private-to-kid** by default
  for the self; **crew-shared** for the crew dream + identity; **room-shared**
  optional (a wall of characters / the shared world map, via the present engine
  #18); **family** gets the keepsake/book (#1), not the raw sheet.
- [x] **Kids see each other** only at the crew/room level a director opts into.
- [x] **Collaboration:** the crew dream is shared; roles can interact (the
  world's people need each other).

## J. Privacy & safety — SETTLED (2026-06-06): the vow
- [x] **No real location, ever** — the only "map" is the *fictional* world's
  geography; we never store a child's real coordinates.
- [x] **Pseudonymous, drawn, fictional self = the privacy WIN.** A *chosen name
  + a drawing* inside a *made-up world* is far less PII than a photo + legal
  name. The world framing is a privacy *feature*, and we lean all the way in.
- [x] **Stored:** drawings (Storage, like photos), chosen names, crews, progress
  — under the same space-scoped RLS + on-device-first rules as everything else.

## K. Onboarding — SETTLED (2026-06-06): two rituals
- [x] **Day-one (whole summer):** *draw yourself* + *choose your name* — short,
  counselor-guided, the birth of your world-self.
- [x] **Week-one (each world):** the world is *revealed* → *join a crew* → *take
  a dream* → *meet its words + people*. A few minutes, counselor-led, then the
  week is play.

---

## The vision — FULLY SHAPED (2026-06-06)
Every section A–K is settled (spine + the 8 fleshed world packs + the second
tier). This doc now describes a complete, coherent kid-facing world to build.

**Next (the bridge to code):**
1. **Design doc** — synthesize this into a buildable spec: the **data model**
   (the `subjects` self + a world / crew / dream / character-sheet layer), the
   **"me" + world screens** (the two age surfaces), and **how each field maps**
   to the systems that already exist (roles #8, supplies #15, action-words #9,
   missions #16). Run **`Agent blast-radius`** on it first — this adds several
   synced tables, so the 6-place checklist + the kid-mode surfaces are in play.
2. **First slice** — on its own branch: *"draw yourself → that's your face"* +
   a bare "me" screen. Smallest real, biggest symbol.

This is a multi-session feature; the docs above are the durable baton.
