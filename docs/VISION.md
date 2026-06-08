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

**The day‑to‑day** — how the afterschool day's real workflows (arrival rush →
blocks → pickup → closeout) map onto the app's surfaces, and where the gaps
are — lives in [WORKFLOWS.md](WORKFLOWS.md). The dream is served by meeting the
day where it actually happens.

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
> blackboard but on the phone and tv/projector" / "for agenda/meeting...
> the anonymous comments/ideas on phone to the web"

Staff aren't just executing a program — they're authoring it. A
**make-our-own-rules / structures** engine, and an **anonymous
brainstorm board for meetings + agendas**: each person drops ideas from
their phone and they appear on the shared web / projected blackboard
with no name attached, so the room can "look at things together"
without ego. Psychological safety as a feature. It rides the
live-session layer (#14).

- **Status:** **anonymous board shipped** (`/board`): phones post ideas to a
  projected wall over Realtime, no names on the wire. The make-our-own-rules
  engine is still undesigned.
- **Lives in:** [LIVE_SESSIONS.md](LIVE_SESSIONS.md),
  lib/features/live_session/board_session.dart

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

### 14. Live sessions — present big, control small

> "if i start a math game... how can i present it through desktop and use
> the phone to coordinate / as a control... do we need sessions?"

A lightweight real-time link between devices: one screen **presents**
(desktop / projector / TV), phones **join to control or contribute**.
For a game, the phone is the remote — it advances slides, the big screen
shows them. For a meeting, every phone is an anonymous voice on the
shared board (#5). Ephemeral by design: this rides **Supabase Realtime**
(broadcast + presence), NOT PowerSync — coordination state isn't durable
child data. Join by a short code (or QR — we already have the rails).

- **Status:** building → **shipped (first game)**: This-or-That now runs
  end-to-end present/control over Supabase Realtime — present on a big
  screen, control from a phone by a join code (`/live`). The same
  `LiveSession` seam generalizes to the rest of the deck + the anonymous
  board (#5) next.
- **Lives in:** [LIVE_SESSIONS.md](LIVE_SESSIONS.md),
  lib/features/live_session/

### 15. The program's supplies, wired into everything

> "we have a list of our inventory... the best way of storing them and
> having them be used by our other things in here"

The program's real-world inventory — markers, paper, balls, craft kits —
as first-class data, not a sticky note. A catalog you maintain once, then
**referenced** by the things that consume it: an activity declares "needs
12 markers," a schedule block surfaces its pack list, a trip its
checklist. Linked by id, never by copied name, so restocking + renaming
happen in one place.

- **Status:** seed → designing ([SUPPLIES.md](SUPPLIES.md))
- **Lives in:** [SUPPLIES.md](SUPPLIES.md)

### 16. Real missions — jobs you actually do, with real evidence

> "roles that actually require real life evidence... helping maintain
> supplies, helping clean around the program... their manuals, how they're
> supposed to be put away... small missions they could truly do if they
> want to save progress... equipment manager, lunch/snack helper... what
> are the rules, what they look like, and actions they could practice"

The **grounded sibling** of the imaginative Role Cards (#8). A *mission* is
a real responsibility in the program — Equipment Manager, Snack Helper,
Cleanup Crew, Supply Keeper — that a kid genuinely **does**. Each has
**rules** (a manual: how it's done, where things go), **actions** to
practice (a real checklist), and leaves **real evidence** (a photo of the
tidy bin, a count). Missions wire into the actual app: the supplies they
maintain (#15), the locations they tend, the manuals that say how. You can
**take one, do it, save progress** — completions accrue into a track record
that feeds the growth book (#1) and *proves* the identity story (#2).
Opt-in and coordinated (who has which job today), never a chore chart.

- **Status:** seed → designing ([MISSIONS.md](MISSIONS.md))
- **Lives in:** [MISSIONS.md](MISSIONS.md)

### 17. Every game speaks the same language

> "all games should be controllable... they all should have the same
> familiar ui and i like the different vibe... how can they all be live...
> how else can they be enhanced... for rhyming, the teacher types what
> students guess, and count it... how can all these speak the same language"

One interaction language under every game — a teacher learns the controls
once and they work everywhere — while each game keeps its own **vibe** (its
color, motion, character). The language is already half-built; the dream is
to finish it so the seams *are* the framework:

- **One content seam** — every game draws from the bank (`ContentSource`,
  #7): the same next / take / remaining everywhere.
- **One control seam** — every game is the same tiny contract: a *state* +
  a reducer `(state, intent) → state` over a shared vocabulary
  (**next · back · reveal · pick · tally · capture**). That one seam makes
  a game controllable three ways at once — tap, **keyboard**
  (`PresenterShortcuts`), and a **phone remote** — because all three just
  send the same intents.
- **One live seam** — because a game *is* a reducer, it plugs straight into
  `LiveSession` (#14): the controller phone sends intents, the presenter
  applies the same reducer. **Every game becomes live for free**, no
  per-game realtime code.
- **One familiar scaffold, many vibes** — a shared `GameScaffold` (the
  glass chrome, the control bar/panel, progress, the reveal beat) so they
  read as one system; per-game theming keeps each one's character.
- **Richer by capture** — a game can *record*, not just advance: in Rhyme
  Time the teacher types each rhyme a student calls out → it counts AND
  banks the good ones (crowd-grow, #7), and can feed the growth book (#1).
  The same `capture` intent fits every game.

- **Status:** seed → designing (the seams — `ContentSource`,
  `PresenterShortcuts`, `LiveSession` — already exist; the unifying `Game`
  contract + `GameScaffold` is the next design)
- **Lives in:** lib/features/activity_runtime/, lib/features/live_session/,
  [LIVE_SESSIONS.md](LIVE_SESSIONS.md), [CONTENT_BANK.md](CONTENT_BANK.md)

### 18. The classroom remote — present/control for *everything*, not just games

> "the point of this is the presentation aspect of it, and the ability to
> control the screen with your phone... even though they're not games, i want
> all of these to be controllable by phone... let's think of more ways we
> could utilize this mechanic"

The phone-as-remote + screen-as-stage isn't a *games* engine — it's a
**classroom remote control** for the shared screen. The teacher walks the
room with the control in their pocket; the projector / TV / desktop is the
stage the whole room watches; nobody's tethered to a laptop. Games were just
the first apps for it. The same contract behind the deck — a *state* + a
reducer over **next · back · reveal · pick · tally** + a stage, present/
control over Realtime (`LiveGameScreen`) — already powers non-game surfaces:

- **Run the day** — a **Now & Next** board (the schedule, big; advance from
  the phone), a room-watchable **visual timer** ("10 min left", start/pause/
  +time from the phone), one-tap **transition cues** (Eyes up / Clean up /
  Line up / Breathe together), a fair-turns **random picker / spotlight**.
- **Decide together** — a **poll / vote** on the real choice (snack, activity,
  book): options big, hands up, the teacher taps the count, the winner glows;
  a **mood / SEL check-in** the same way.
- **Celebrate & connect** — a **photo-of-the-day slideshow / day-in-review**
  (perfect at pickup as families walk in), **shout-outs**, a morning
  **welcome board**.
- **Learn** — **read-aloud** pages (TTS-narrated for the pre-readers),
  **word / action-word of the day** (#9), a **circle-time board** (day / date
  / weather / helper-of-the-day).

The only new primitive any of these needs is **time** (the timer's clock);
everything else is the tap-driven vocabulary that already exists. The work is
to (1) name it for what it is — a **"Present" / "Room screen"** capability,
not "games" — and (2) give existing content (the schedule, the photo feed) a
**Present mode** rather than rebuilding it.

- **Status:** seed (the engine — `GameDefinition` + `LiveGameScreen` — exists
  and is proven live on This-or-That, Riddles, Fact or Fib; the non-game
  surfaces are the next build)
- **Lives in:** lib/features/games/, lib/features/live_session/,
  [GAMES.md](GAMES.md)

---

## New dreams land here

A dated log so nothing spoken is lost. Promote each into a theme above
once it has a home.

- **2026-06-07** — **The "why", said plainly.** In the user's words: *"this
  is going to be where we invest in our kids… the subscription and the
  scale, proximity, documentation, legacy. Because one day, if AI takes over
  the world, at least we can still have imagination. This is human-first
  philosophy in code — a different world. If we could control it: what are
  our values, our dreams, our wants, and still live in harmony?"* The app is
  not a logging tool; it's a place to **invest in a child's imagination and
  prove it happened.** Every feature should answer: does this help a kid
  become more themselves, and does it leave a record a family can hold? The
  end deliverable: **the app lays out the SUMMER BOOK for each child — each
  history, each different world** — so the proof of who they became goes home
  with them. (Threads: the Book, the Showcase/legacy, the character sheet.)
- **2026-06-07 (cont.)** — **Two layers of skin.** A child's experience is
  themed twice: (1) the **ROOM skin** — a physical room's *permanent* theme
  (Space, Underwater, Urban, Safari, Travel) that decorates the setting for
  whoever's in that room; and (2) the **WEEKLY skin** — the curriculum world
  the whole program is in that week (Me → Stories → … → Us). The room sets a
  standing vibe; the week sets the content. A kid in the Safari Room during
  Week 3 (World of Nature) lives inside both at once. (Thread: room→skin on
  `groups`, the week schedule already drives the weekly skin.)
- **2026-06-07 (cont.)** — **The day, on rails — "Play today."** In the
  user's words: *"we could cast this to present and it's time bound and
  context bound, room bound, all that, and play these in sequence without
  the teacher trying to find where everything is."* All the pieces exist
  (world hero, verbs, the rule, Watch → Do, the Big Thinking game, the
  activity, the closing reveal) but they live on different screens, so the
  teacher is a DJ hunting for tracks. The dream: **one "Play today" and the
  day unfolds as an ordered, full-screen run of show** — assembled from
  *this room × this week × this moment* — that the teacher just advances,
  hands free of the menu. The day plays itself; the teacher stays with the
  kids. **Time-bound** (the run is the day's arc; can start at the beat for
  "right now"), **context-bound** (the live curriculum world + its thinking
  game), **room-bound** (this cohort, its skin). Built on the present/cast
  spine so it casts to the room. (Thread: `buildDayRun` + the `/play-today`
  immersive runsheet, the cast cockpit. Next: two-device cast of the full
  run + auto-advance toggle.)

- **2026-06-01** — **Group discussions** by topic + age-appropriateness,
  with a library to back them (→ dream #6). **People role deck** —
  professions/people with their own icons + habits (→ dream #8).
- **2026-06-01 (cont.)** — **Live sessions**: present a game on the
  desktop/projector, control + coordinate from the phone — the shared
  real-time layer (→ dream #14). The **anonymous meeting/agenda board**
  (phone → web, no names) rides it (→ dream #5). And **supplies /
  inventory** as wired-in first-class data the activities consume
  (→ dream #15).
- **2026-06-01 (cont.)** — **Real missions / jobs** with real-life
  evidence (Equipment Manager, Snack Helper, Cleanup, Supply Keeper…):
  rules + manual, practiceable actions, photo/count evidence, save-progress
  + coordination, wired to supplies (#15) + locations + the growth book
  (→ dream #16).
- **2026-06-01 (cont.)** — **More games**: shipped Riddles + Mindful Minute,
  then designed a **20-game deck** around *phone-as-remote, desktop/web-as-
  presentation* — every game a (Presentation, Control, sometimes Secret)
  trio. Catalog + the two-device model in [GAMES.md](GAMES.md); Charades is
  the standout two-device unlock (→ dreams #4 + #14).
- **2026-06-02** — **The classroom remote**: the *present/control mechanic*
  is the product, not the games. ALL shared-screen moments should be phone-
  driven — a Now & Next schedule board, a visual timer, real polls/votes, a
  mood check, a photo day-in-review, transition cues, read-aloud, a random
  picker. The `GameDefinition` + `LiveGameScreen` engine already supports
  all of them but the timer (which needs a clock primitive); the move is to
  reframe it as a "Present / Room screen" capability and give existing
  content a Present mode (→ dream #18).
- **2026-06-02 (tangent, remember)** — **Vehicle check-in/out → guided photo
  capture.** Beyond the safety checklist, check-in/out should REQUIRE photos
  via a *guided* flow: the camera stays open and walks the staffer through
  exactly what to shoot, shot by shot (e.g. front, odometer/mileage, seats /
  every-child-out sweep, fuel, any damage), each with a named prompt, before
  the checklist can complete. Pairs with the planned shared
  `face_aligned_camera.dart` / on-device camera widget + the Storage photo
  path (photo_url on the row, bytes in the bucket). BUILT (Waves A–C,
  `feat/vehicle-photos`): configurable per-vehicle shot list + the guided
  camera + the gate + review. (→ vehicles feature.)
- **2026-06-02 (cont.)** — **Vehicle check as a safety RITUAL, not paperwork.**
  > "for the vehicle, picture first, then the checklist, with an 'all check'
  > capability, etc... what else"

  Reshape the check-in/out flow: **photos FIRST** (capture the required shots
  at the vehicle — esp. the empty-cabin sweep the moment you arrive), THEN the
  checklist. A **"Mark all OK"** bulk action (real inspections are mostly all-
  good; tapping 10 items is friction) + **configurable checklist items** per
  vehicle (capabilities, like the photo shots). The STAR addition: a
  **roster headcount** — confirm WHO boards at check-out and tap each child
  OFF at check-in; the count must hit zero and match the empty-cabin photo.
  That's the actual hot-car prevention (the photo is proof; the name-by-name
  sweep is the act). More candidates: destination/field-trip link + expected-
  return alert, odometer carry-forward + validation (trip miles), Unsafe →
  block + notify the director, maintenance/registration-expiry reminders at
  check-out, optional two-person co-sign on the empty-cabin. (→ vehicles.)
- **2026-06-03** — **The app as a collection of distilled THINKING TOOLS —
  one source of truth, many contributors.**
  > "i want this to be a collection of tools, like 'Systems Thinking'... for
  > communication, for teaching, for whatever you do... youtube/social media
  > are too noisy, how can we distill all information to one source of truth...
  > but many contributors"

  The deeper *why* under everything: the app is a **library of thinking
  tools** — mental models / frameworks / methods (Systems Thinking, First
  Principles, Socratic questioning, Think-Pair-Share, the 5 Whys, Inversion…)
  for thinking, communicating, teaching, doing — distilled, **runnable**, and
  **refined by many**. The **anti-YouTube**: where social media is noise
  optimized for engagement + recency (N rival videos, none authoritative,
  decaying into a feed), this is **signal distilled to ONE canonical, usable
  form per tool**, which the next contributor *sharpens* rather than competes
  with.

  The reframe: the games/activities are ALREADY this genre, for kids
  (This-or-That = articulate a preference + the reasoning; Story = collaborative
  creativity; Discussions = Socratic; As-If = perspective-taking). The dream
  makes "a library of thinking tools" the ORGANIZING idea, opens it to
  contributors, and reaches past the classroom ("whatever you do").

  The substrate already exists — a deepening, not a pivot:
  - **A contract per tool** (like `GameDefinition`) — structure forces clarity
    + comparability; the format IS the de-noiser (what it's for / when to reach
    for it / how to run it / one worked example), not a 12-minute ramble.
  - **Distillation TIERS, not a feed** (the content-bank model): a curated
    floor + crowd contributions promoted as they prove out + de-dupe by
    fingerprint → ONE canonical entry per tool, refined by many
    (Wikipedia-for-runnable-tools, not rival videos).
  - **Runnable, not just readable** — the present/control engine (#18): you RUN
    Think-Pair-Share with the room; you don't watch a video about it. The tool
    IS the experience.
  - **Combinatorial generation** (the content engine): a few distilled
    primitives → endless fresh, never-noisy instances.

  - **Status:** vision / undesigned — likely a NORTH-STAR-level reframe.
  - **Open questions before coding:** who contributes (program staff / a wider
    professional community / the public)? what IS a "tool" — a runnable
    activity (the games), a reference card (the Toolkit "sentences you can
    say"), or both? is the audience still early-childhood, or does "whatever
    you do" genuinely broaden it? "one source of truth" curated by whom — an
    editorial layer, algorithmic promotion, or community consensus? how does a
    contributed tool earn promotion from crowd → curated?
  - **Threads:** #2 (this is you + your tools), #7 (content libraries), #17/#18
    (the game contract + present/control engine), the content freshness engine.
- **2026-06-06** — **The summer IS a Different World — each child builds an
  in-world self.** The kid-facing counterpart to the thinking-tools reframe:
  the summer isn't a program a child *attends*, it's a world they *live in*
  and construct an identity inside, over the whole summer.
  > "for the whole summer, it is a different world. their pictures are their
  > first drawing of themselves... they choose their names, their age is how
  > long they've completed dailies... birthday... they choose their culture,
  > their words, etc... map their location, get to see their world differently
  > through roles... they'll have the verbs, their abilities... and their
  > skills are things that are utility / survivability"

  Each child has a **character sheet** — but every field is *earned or chosen,
  never just given*:
  - **Avatar = their first drawing of themselves.** Not a photo — on day one
    the child draws who they are; that drawing is their face in the world.
    (→ #1: the drawing is the first page of their book.)
  - **Name — chosen.** A world-name they pick, not the one on the roster.
  - **"Age" = dailies completed.** Age isn't years lived; it's how many daily
    missions you've done. You grow *older in the world* by showing up and doing
    the work — progression as identity. (→ #16 missions / dailies.)
  - **Birthday** = the day they entered the world (first daily / first day).
  - **Culture — chosen.** They pick a culture; it colours their world.
  - **Words — chosen.** Their Action Words become *theirs* — a personal
    vocabulary they carry. (→ #9 Action Words of the Day.)
  - **Location — on a map.** Each child sits somewhere on a world map; the
    program is a geography, not a roster.
  - **Roles — how you see the world differently.** Roles aren't jobs you're
    assigned; they're LENSES — step into one and the world looks different.
    (→ #8 role decks, #2 identity-as-self-knowledge.)
  - **Verbs = abilities.** The action words are also what you can DO — your
    verbs are your powers. (→ #9.)
  - **Skills = utility / survivability.** Practical real-world competences —
    not RPG stats, but things that help you *do and endure* (the mission
    competences, made legible as a skill set).

  The reframe: every kid-facing thread — the growth book (#1), identity cards
  (#2), brain-break makes (#3), role decks (#8), action words (#9), real
  missions (#16) — are FACETS OF ONE THING: a child constructing themselves
  inside a world over a summer. The **character sheet is the spine** that
  connects them. It's the kid-side answer to "what are we even doing": not
  entertaining them, not testing them — giving them a world to *become
  someone* in, and a record of who they became.

  - **Status:** vision / undesigned — a NORTH-STAR-level reframe of the
    kid-facing experience (counterpart to the 2026-06-03 thinking-tools reframe
    of the staff-facing side). Theme-worthy; fold up once it has a home.
  - **Open questions before coding:** what does a child SEE — a "me" screen
    (the character sheet), a world map, both? how literal is the RPG framing
    (do we say "abilities / skills / age" to a 6-year-old, or is that
    staff/parent-facing language over a playful kid surface)? who sets it up —
    kid alone, kid + counselor, director-curated menus (culture / words /
    roles from a fixed set vs free)? how does "age = dailies" show — a number,
    a badge, a growing avatar? does the avatar get RE-drawn over the summer
    (you draw yourself again at the end — growth made visible)? is the map
    real geography or an invented world? what's private-to-kid vs
    shared-to-room vs sent-to-family?
  - **Threads:** #1 (the book / output), #2 (identity + tools), #3 (makes),
    #8 (roles as lenses), #9 (action words = verbs), #16 (missions = dailies
    = age). The CLAUDE.md "Showcase / growth arc" is the OUTPUT; **this is the
    PLAYER** that produces it.
- **2026-06-06 (cont.)** — **A NEW world every week — themed worlds, a crew, a
  dream.** The "different world" is plural: the summer is a JOURNEY through
  worlds, a new themed one each week.
  > "they're going to different worlds... every week they'll go to different
  > worlds... they'll be pirates, they'll be in outer space, under the sea...
  > they'll have their crew... they'll have a dream... in this world there are
  > people, things, words, dreams, culture"

  Two layers: the **persistent self** (the character sheet) travels through a
  **new themed world each week** — pirates / outer space / under the sea / ….
  Each world is a populated place — **people, things, words, dreams, culture** —
  and inside it the kid has a **crew** (a team) and a **dream** (a quest). The
  week-shape: arrive → join a crew → take a dream → live the world → carry the
  growth forward. This makes **"one engine, many worlds" (#13) literal on the
  KID side**: each world is a **themed content pack** that re-skins what we've
  built — roles (#8) = its people, supplies (#15) = its things, action words
  (#9) = its words, missions (#16) = how dreams are chased. New world = new
  pack, same engine.
  - **Status:** vision / undesigned — the full shape + a shaping checklist now
    live in **[WORLD.md](WORLD.md)** (this is the home the 2026-06-06 reframe
    was waiting for).
  - **Threads:** the persistent self (above) + #8 / #9 / #13 / #15 / #16. CREW
    likely maps to classroom **groups**; DREAM likely maps to **missions**.

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
