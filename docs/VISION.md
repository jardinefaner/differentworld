# Different World — the dream

This is the **why**. Not the schema, not the roadmap, not the sprint —
the thing all of those serve. It's a living document of what this app is
*for*, written to survive every session boundary so no dream gets lost
in a transcript.

**The rule:** when a new dream is spoken, it lands here the same turn —
dated, in the dreamer's own words where possible. Dreams are never
deleted, only moved from *seed* → *building* → *shipped*. The plan for
*how* lives in [ROADMAP.md](ROADMAP.md) and
[ACTIVITY_ROADMAP.md](ACTIVITY_ROADMAP.md); the *why* lives here.

---

## North star

> A different world for kids — and for the people who show up for them
> every day.

Most software for childcare is a **compliance ledger**: attendance in,
incident reports out, a database of children. Different World inverts
that. It's built on one belief:

**Every child's time here is a story worth telling, and every adult here
is a whole person with a way of working that the tools should fit — not
fight.**

So the app optimizes for three things the ledgers don't:

1. **Making, not consuming.** Screens that give kids a *reason to
   create* — imagination first.
2. **Becoming, not recording.** A child isn't a row of data; they're a
   book being written. An adult isn't a role; they're an identity with
   tools.
3. **Breathing room.** Calm, beautiful, never cluttered. The interface
   should feel like a deep breath, not a dashboard.

Everything below is in service of that.

---

## The dreams

Each dream has: the **spark** (often a direct quote), what it *means*,
its **status**, and where the design/plan lives.

### 1. Every child becomes their own book

> "they document because one day, each will be their own book"

Every artifact a kid makes — a drawing photographed, a voice note, an
"as if" performance, a role they chose, a survey answer, a moment a
teacher caught — feeds a story that compiles over time. Daily highlight →
weekly wrap → term portfolio → **year-end keepsake**. The "drawing
becomes a film" framing: metaphorical (compilation + voiceover + music),
not literal animation. The child leaves with *something that is theirs*.

- **Status:** seed (data exists across `attachments` / `entries` /
  `survey_responses`; the curation + render pipeline is undesigned)
- **Lives in:** CLAUDE.md → "Showcase / growth arc (vision, undesigned)"

### 2. "This is you, and these are your tools"

> "id cards for each... are they a visionary, doer, protector, i don't
> know what they are, help... this is you and these are your tools"

Every person — staff and, eventually, kids — has an **identity card**:
traits, a work-style, a communication-style, and a set of tools the UI
turns on or off based on who they are and what they can do. Not
role-as-permission-gate; role-as-*self-knowledge*. The 8 archetypes we
named: **Visionary, Doer, Protector, Anchor, Connector, Sage, Seeker,
Beacon.**

- **Status:** building (8 archetypes named + role-card mechanic shipped;
  the per-person ID card + togglable affordances is the next lift)
- **Lives in:** [IDENTITY_SYSTEM.md](IDENTITY_SYSTEM.md),
  [ROLES_SMART_PRACTICE.md](ROLES_SMART_PRACTICE.md)

### 3. Give them a reason to execute — imagination

> "give them reason to execute... imagnation"

Brain breaks aren't filler videos — they're **invitations to make
something**. Draw a tile and watch it become a pattern. Photograph the
moment into a collage. Become a bee for the day and leave proof behind.
The screen is a launchpad back into the physical room, not a destination.

- **Status:** shipped + growing (Pattern Maker, Photo Studio, Collage,
  Role Cards live; more activities on the roadmap)
- **Lives in:** [ACTIVITY_ROADMAP.md](ACTIVITY_ROADMAP.md),
  [ACTIVITY_RUNTIME.md](ACTIVITY_RUNTIME.md)

### 4. No typing, no right/wrong, teacher-paced

> "the games are not for typing... no right or wrong... teacher paced"

Every game is **host-present**: the prompt shows big, the *room* answers
out loud, the teacher reveals and advances. No keyboards handed to kids,
no scores, no red X. Play, not a quiz. This-or-That is the reference
shape; Beat the Letter and Math Game were reshaped to match.

- **Status:** shipped (This-or-That, Beat the Letter, Math Game; Many
  Paths reshape pending)
- **Lives in:** [ACTIVITY_ROADMAP.md](ACTIVITY_ROADMAP.md) Wave 2

### 5. Teachers make their own rules — and think together

> "for teachers we're going to create our own rules... when
> brainstorming, we see all comments but not from who... like a
> blackboard but on the phone and tv/projector"

Staff aren't just executing a program — they're authoring it. A
**make-our-own-rules / structures** engine, and an **anonymous
brainstorm board**: ideas appear on the phone and the projected
blackboard with no name attached, so the room can "look at things
together" without ego. Psychological safety as a feature.

- **Status:** seed (rule engine + anonymous board both undesigned)
- **Lives in:** here (to be promoted to a design doc when we start)

### 6. Group discussions, by topic and age

> "add group discussions, which are discussions and based on topic, and
> age appropriateness... library for that"

A host-present discussion activity: pick a **topic** and an **age band**,
get a curated prompt the room talks through, go deeper or move on. A
real **library** of discussion starters — kid-safe, age-graded — that
grows the way the rest of the content bank does.

- **Status:** building (2026-06-01)
- **Lives in:** [CONTENT_BANK.md](CONTENT_BANK.md),
  [ACTIVITY_ROADMAP.md](ACTIVITY_ROADMAP.md)

### 7. Content libraries — answer-first, age- and topic-graded

> "all math could be created in this engine, with ai help... start with
> the answer first and create questions for those... questions of the
> day, puzzles of the day, word of the day... random or per topic per
> age range"

A growing bank of content: math, science, questions to ask, words,
puzzles — **of the day**, or on tap. Two tiers: **generated** (math is
free + infinite, no AI needed) and **curated/brokered** (discussions,
questions, science — authored once, reused, grown). The generation
philosophy: **start from the answer, build questions toward it.** Every
item tagged by topic + age range.

- **Status:** building (local content bank live; `content_items` DB
  table + brokered-AI refill + daily feeds pending)
- **Lives in:** [CONTENT_BANK.md](CONTENT_BANK.md)

### 8. Role decks beyond animals

> "for the role cards, i like the animals, but what about people...
> professions... how about space, planets, games i don't know...
> books... let's brainstorm" / "for the roles, we could have people,
> icons, and they will have their own habits and things"

The role-card mechanic (3 habits, 3 artifacts, 1 trait) is theme-
agnostic. So: **theme decks.** People & professions (each with their own
icon + habits), space & planets, books, games. A kid can be a Bee one
day and an Astronaut the next.

- **Status:** building (animals/nature shipped; People deck 2026-06-01)
- **Lives in:** [ROLES_SMART_PRACTICE.md](ROLES_SMART_PRACTICE.md)

### 9. Action Words of the Day

A kid-mode surface where each kid picks (or is assigned) **3 verbs** for
the day — "explore," "share," "create" — with kid-friendly descriptions
and voiceover for pre-readers. Their picks surface back to staff
(today's room words) and to family ("today {Name} chose: …").

- **Status:** seed (open design questions logged)
- **Lives in:** CLAUDE.md → "Action Words of the Day (vision,
  undesigned)"

### 10. Breathable, beautiful, one visual language

> "declutter... more negative space, breathable" / "the chrome must be
> floating glass like the omnibox, no solid backgrounds" / "color the
> whole screen"

Calm by default. Generous negative space. One chrome language —
**floating glass** — everywhere, never a solid bar. Immersive activities
fill the screen with color. A single illustrator pass for empty states +
a wordmark-as-system across login, onboarding, exports.

- **Status:** building (floating-glass chrome + auto-clearance shipped;
  Screen Rubric A6/A7 enforce it; empty-state illustration pass pending)
- **Lives in:** CLAUDE.md → floating-glass section + [SCREEN_RUBRIC.md](SCREEN_RUBRIC.md)

### 11. Always an exit — never a trap

> "how do i exit from a brain break??"

A child (or a teacher) must *always* be one obvious tap from out. No
locked screens with no door. This is now a **blocker-level rubric rule**
(A6), not a hope.

- **Status:** shipped (rubric A6; de-lock pass across all activities)
- **Lives in:** [SCREEN_RUBRIC.md](SCREEN_RUBRIC.md)

### 12. Minimal data, on the device, privacy as a vow

> "minimal data collection... everything is on the device"

Collect the least that makes the story possible. Keep it local-first.
Children's PII is treated as sacred — private storage, signed URLs, no
PII in logs, no row-level analytics. A parent can export and delete.

- **Status:** shipped + ongoing (offline-first architecture, private
  photo bucket, secure-screenshot, no-PII-logging are invariants)
- **Lives in:** CLAUDE.md → Privacy & security + architecture invariants

### 13. One engine, many worlds

The structural core (Space / Member / Subject / Group / Entry) is
domain-agnostic so the same app can serve afterschool (the first home,
ages 4–12), and later infant care, preschool, K-12 enrichment — without
forking. Afterschool feels right on day one; the rest is reachable.

- **Status:** shipped (universal rename done; afterschool defaults first)
- **Lives in:** [NAMING.md](NAMING.md), CLAUDE.md

---

## New dreams land here

A dated log so nothing spoken is lost. Promote each into a theme above
once it has a home.

- **2026-06-01** — **Group discussions** by topic + age-appropriateness,
  with a library to back them (→ dream #6). **People role deck** —
  professions/people with their own icons + habits (→ dream #8).

---

## How to keep this alive (for future me)

- A new dream spoken → add it under **New dreams land here** the same
  turn, with the date and a quote. Then fold it into a theme (#1–#13) or
  add a new theme if it doesn't fit.
- A dream ships → update its **Status** (seed → building → shipped) and
  link the feature in [FEATURES.md](FEATURES.md).
- Never delete a dream. A shelved one becomes "shipped: no" or moves to
  CLAUDE.md "intentionally deferred" with a pointer back here.
- This doc answers "what are we even doing?" Keep it readable in one
  sitting — if a theme needs depth, it gets its own design doc and a link
  from here.
