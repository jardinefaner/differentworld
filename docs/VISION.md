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

- **2026-06-19** — **The app IS a slide deck that coordinates the room — each
  block self-contained: all its info AND its actions, together.** In the user's
  words: *"this app basically creates slides that coordinate the room, all the
  necessary info and actions are within this block."* This is the organizing
  metaphor the whole app has been circling — it names what the cockpit, the
  cast/present spine, the schedule blocks, and the just-shipped bento tiles all
  are: a **deck of slides**, shown one beat at a time, each a self-contained
  **block** that carries everything the moment needs — the info to read AND the
  actions to take — so the host runs the room from one block, never hunting
  across screens. It crystallizes #14 (present big / control small), #18 (the
  classroom remote — present/control for *everything*), #13 (the day as a fixed
  routine of blocks), and the one-visual-language (#10) into a single shape:
  **the day is a run-of-show; each beat is a slide; the slide holds its own
  info + actions.** The bento work IS this realization — a bento tile is a
  self-contained block, and the global "Bento everywhere" switch makes the whole
  app read as blocks; the cockpit's "ONE beat at a time" is the deck advanced
  one slide at a time. The lift from here: make the unit **explicit** — a
  `Block` / `Slide` primitive that any moment (a schedule block, a game, an
  activity, a morning intro, a pickup) renders into: a tile that shows its info
  and exposes its actions inline, castable to the room (present) while the phone
  advances the deck (control). (Threads: #14 `LiveSession` present/control, #18
  the present/control reducer + the classroom remote, #13 the day-run engine /
  run-of-show, the cockpit `cockpitBeatProvider`, the bento tile + `BentoModule`,
  `schedule_blocks` + the live-block capture context, docs/LIVE_SESSIONS.md +
  docs/COCKPIT.md. **Open forks:** (a) is the "slide" the SCHEDULE BLOCK — the
  day's timed run-of-show — or ANY moment (a game, an intro, a pickup)? Likely
  both: the schedule is the default deck, any activity can be cast as a slide.
  (b) Does "all actions within the block" mean the block is the ONLY surface — a
  true one-slide-at-a-time cockpit — or the bento tile is the block and the deck
  is the scroll? The cockpit fork ⑤ (Today vs. one-beat) is exactly this
  question.)
- **2026-06-13** — **The day is a fixed ROUTINE: morning intro, then play +
  write on paper, cumulative.** In the user's words: *"i want the class to be
  routine, all the worlds intro in the morning, and rest are play time and
  writing their answers on paper, cumulative."* The day has a standing shape,
  the same every day: the **MORNING is the world intro** — the ritual open
  where the room is introduced to its world (the week's world, cast big), and
  the **REST of the day is PLAY TIME + kids WRITING THEIR ANSWERS ON PAPER** —
  by hand, analog, no screens in their faces (extends dream #4, "no typing").
  And it's **CUMULATIVE** — the paper answers build over the term into each
  child's book / portfolio (the proof of who they became, → dream #1). The
  app's three jobs in this routine: (1) **open the morning** with the world
  intro on the present/cast spine; (2) **prompt** the questions the kids answer
  on paper (the wall questions, the day's verbs); (3) **capture the paper back**
  so it accumulates — staff photograph the sheet → attachment → the Summer
  Book / growth arc. The screen is the launchpad and the ledger; the *thinking*
  happens on paper, in the room. (Threads: `/play-today` run-of-show + the
  day-run engine, the wall questions, the two skins room×week, Summer Book #1,
  time capsules, observation photos → attachments. **Open forks:** (a) is it
  ALL ten worlds intro'd each morning, or the WEEK'S world each morning as the
  standing ritual? (b) does the app photograph the paper to make it cumulative
  — or stay fully analog with staff curating a few into the book?)
- **2026-06-13 (cont.)** — **Role is the spine: your role reshapes the whole
  screen — different tools for different roles.** In the user's words: *"i want
  roles to be a huge part of this… your role changes the UI and functions of
  your screen, different tools for different roles."* This **escalates dream #2**
  ("this is you and these are your tools") from *toggle a few affordances* to
  *the app reconfigures around who you are* — the home, the toolset, the
  available functions all change by role, so two people open the same app to two
  different surfaces. Three role axes already live in the codebase, and "role"
  may mean any/all of them: (1) **staff job** — director / lead / teacher /
  assistant / specialist, today a capability gate via `viewerProvider`; (2) the
  **8 archetypes** — Visionary / Doer / Protector / Anchor / Connector / Sage /
  Seeker / Beacon (identity cards, dream #2); (3) the **kid classroom job** —
  the verb-jobs (Mover / Helper / Keeper…) with `helperSays` scripts (dream #16,
  the staff layer). The gate already exists (capabilities); the lift is
  **role-as-home**: a tailored landing + tool palette per role, not one app with
  hidden bits. (Threads: dream #2 + IDENTITY_SYSTEM.md, dream #16 missions/
  verb-jobs, the staff ladder, `viewerProvider` / capabilities. **Open fork:**
  which axis drives the screen — the staff job, the archetype, or the kid job?
  Likely layered: staff job picks the *home*, archetype tunes the *tools*, kid
  job reshapes the *kid-mode* surface.)
- **2026-06-13 (cont.)** — **Digital manipulatives: democratizing the systems
  to think without AI.** In the user's words: *"just like we have manipulatives
  and building blocks, that's what we're doing too… we're giving them the
  systems to function without AI… we're democratizing education… and also,
  giving them the tools using the phone."* The framing that ties the whole app
  together: the thinking tools (Systems Thinking, the 12 verbs, the worlds, the
  role decks) are **manipulatives for the mind** — the digital equivalent of
  blocks and counters a child moves with their hands. The phone is the
  *delivery* of those manipulatives, not the destination (it hands the tool
  over, the thinking happens off-screen — paper, room, out loud). **Democratizing
  education** = every child and every teacher gets the same first-class thinking
  systems, free of needing an AI to do it for them — so when the machines can
  do everything, a kid still knows how to *imagine and reason*. (Sharpens the
  north star + the 2026-06-07 "why" + dream #494 thinking-tools; the test for
  any feature: is it a manipulative that builds a capacity, or a crutch that
  replaces one?)
- **2026-06-13 (cont.)** — **One phone, MANY screens — opt-in screen control.**
  In the user's words: *"for the presentation, each user can let their screen be
  controlled by one user… instead of one phone, one screen, now it's one phone,
  many screens."* Extends dreams #14 + #18. The present/cast layer is *framed*
  today as one-phone-one-screen (the cast cockpit drives a single receiver), but
  the **Realtime broadcast spine already pushes canonical state to EVERY device
  on the join code** and re-broadcasts on each presence join — so 1→N is already
  true at the transport level; presence already counts the joiners. The dream
  promotes it to first-class: a device **opts in** ("let the teacher drive my
  screen"), and one host phone drives them all at once — every kid's tablet
  becomes a slaved screen of the one presenter. (Thread: `live_session.dart`
  broadcast/presence, cast cockpit/receiver. **Open fork:** *mirror-all* —
  every screen shows the same thing the host drives (nearly free on today's
  broadcast) — vs *per-screen control* — the host drives each device
  independently (screen A on slide 1, B on slide 2), which needs per-target
  addressing on top of the broadcast. Start with mirror-all; per-screen is the
  bigger unlock for stations/centers.)
- **2026-06-13 (cont.)** — **The phone as the live classroom INSTRUMENT —
  conduct the room's screen, moment to moment.** In the user's words: *"i want
  this phone to be a tool to really run the class during, too. like when
  reading, i tap a word on the phone, and that's what gets bolded/highlighted…
  like when a child wants me to spell something because they're writing, i
  click an avatar on the phone, type the spelling, present screen shows the
  avatar and the word next to each other… all must fit in screen."* The present
  layer isn't only pre-built slides/games — it's a **live canvas the teacher
  plays from the phone** during class, for spontaneous micro-moments. Two named
  instruments: (1) **Tap-to-highlight reading** — shared text up big; the
  teacher taps a word on the phone and THAT word bolds/highlights on the room
  screen (follow-along reading, teacher-paced). (2) **Spell-for-me** — a kid
  asks how to spell something while writing; the teacher taps the kid's avatar,
  types the word, and the room screen shows **avatar + word, side by side,
  big.** The unifying law: **everything auto-fits the screen** — big, legible,
  no scroll, scales to the content. The build is closer than it sounds: the
  **Speak engine already has active-word highlighting + `FittedBox` auto-fit +
  15 big-text layouts**, and the broadcast/cast spine + one-phone-many-screens
  push it to the room. The move: a **live "board" / instrument mode** — a phone
  control surface with quick instruments, each rendering an auto-fit big layout
  to every screen. Extends dream #18 (the classroom remote is the product, not
  the games) into the *unscripted* moment. **Candidate instruments** (the "what
  else"): highlight-a-word · spell-for-me (avatar + word) · reveal a word/letter
  at a time · sound-it-out (syllables/phonemes, tap each) · spotlight/point at
  part of an image · big number + live tally (count together) · whose-turn
  (push a kid's avatar big) · show-and-tell (push a kid's drawing/photo big) ·
  two-up compare · attention/quiet cue · hold/freeze the current thing. Each is
  a small "instrument" on one shared spine. (Threads: `speak/` engine,
  `live_session.dart` broadcast, the present/cast cockpit, one-phone-many-
  screens. **Design law to enforce everywhere on the present surface:
  auto-fit — text scales to fill, never scrolls, never clips.**)

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
- **2026-06-07 (cont.)** — **The STAFF layer — the adults run on rails too,
  and the 12 verbs are one spine across three lives.** Everything so far is
  kid/content-facing. The new axis: the app trains and choreographs the
  *adults*. Three novel pieces. (1) **A staff growth ladder** — Shadow →
  Extra Hands → Co-Pilot → Conductor — earned by practice not tenure, with
  can-do / not-yet gating, mirroring the kid's own character arc (the kid
  becomes a character; the helper becomes a Conductor). (2) **A staff-facing
  runbook — "Play today" for the grown-ups**: every moment of the day in
  three lanes — what the LEAD does, what the HELPER does, and IF IT BREAKS
  (the contingency column nobody builds). The anti-burnout, anti-"where's-
  everything" twin of the kid run. (3) **The 12 verbs as ONE vocabulary,
  three lenses**: a kid's *identity* (the verbs they pick — built), a kid's
  *job for the day* (picked CARRY → you're the Mover, with a helper SCRIPT
  of exact words to say), and a *staff skill* (CARRY L1 = carry materials,
  L3 = carry the room's energy). Plus **scripted micro-language**
  (`helperSays` / `helperGuide`) — telling a nervous new helper *exactly
  what to say* — the digital "Sub Box": any human who walks in can open it
  and run the next hour. (Threads: extend the existing Missions feature with
  verb+level rather than fork it; ties to the Pat/substitute seed
  `leadSubstituteMemberId`; the staff ladder is a new surface. "Invest in
  our kids, not AI" includes investing in the humans who hold them.)

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
- **2026-06-08** — **One day, minute by minute — the operating model.** The
  user wrote the whole day out, 6:45 setup → departure → parent messages, every
  minute labeled with the primitives it activates and every person's job named:
  the **teacher sees**, the **helper models** (writes their own sentence, draws
  alongside), and the **kids run the room through their picked verbs** — Movers
  (CARRY) carry, Navigators (FLOW) lead, Scouts (WATCH) report, Spark Plugs
  (PLAY) start the games. The heart is **Verb Hour**: play it → name it (turn it
  into a word: "COMMUNICATION") → bridge it (radio → your mom at work → a clay
  tablet 3,000 years old) → question it (to the Wall) → mission check. The
  load-bearing constraint is that **the app stays nearly silent**: *"Total
  screen time in the entire day: under 12 minutes. All teacher-facing. Zero
  kid-facing. The app touched the day four times — mood (5 sec), verb picks
  (10 sec), picking an activity (15 sec), parent messages (10 min after kids
  leave). Everything else was human."* The mantra: ***"The room does the
  teaching. The verbs do the guiding. The teacher does the seeing. The app does
  the remembering."*** This is both the dream AND the app's **acceptance
  contract** — every screen is measured against *"would this survive in that
  day, at that footprint?"* The full minute-by-minute lives in
  **[THE_DAY.md](THE_DAY.md)**. (Threads: the 11 primitives; the present/cast
  spine; the four app-touch surfaces — mood entry, Action Words picks, the
  `matchActivities` matcher, `buildParentMessage`.)
- **2026-06-08** — **Everything that brings the system to life — the asset
  manifest.** The full catalog of what gets MADE: physical cards (verb / world-
  reveal / spell-word / wall-question / if-i-were / timer), the custom journal
  (lined-left / blank-right, a mirror sticker on the last page — *"the last page
  of every book is you"*), the room environment (the Wall Kit, the Journey
  Line, per-world transformation kits), wearables (verb bracelets, world pins,
  name tags), audio (a fixed 9:00 chime, per-spell sounds, a reveal sound, the
  kids' four-note anthem *made by them, not for them*), digital (reveal
  animations, the parent daily card, the summer report, the collection poster),
  video (atmospheric world intros, the showcase film), and the **8 print
  bundles** — the code-actionable core. The operating rule: *"already laid out
  before printing — teachers don't need to do anything; every printable is
  pre-formatted to how it gets printed."* And the closer: *"The assets
  disappear. The teacher appears. The kid is seen. That's the product."* Full
  manifest + the print-readiness audit (what the `/print` toolkit covers vs. the
  8 bundles) live in **[ASSETS.md](ASSETS.md)**. (Threads: the print toolkit,
  the poster engine, the summer book, the daily content banks that are still
  missing.)
- **2026-06-08** — **The season, synthesized — "how can we synthesize
  everything for a 10-week program."** The zoom-level ABOVE the day: how a
  single 10-week / 50-day program is set up, unfolds, and leaves each child a
  book. The spine is **one date** (`program_start_date`) that drives both the
  weekly curriculum (`ten_worlds`) AND the 50-day journey (`world_blocks`); the
  six zoom levels (minute → day → fortnight → week → season → child) each pair a
  content pack with a cast surface and a human job; the 12 verbs thread through
  as identity / job / skill; the per-child `action_words` accrete into the
  growth book. The synthesis surfaced the **standing seam**: the two content
  packs encode **two different journeys** (5 immersive fortnight worlds vs 10
  weekly foci) that don't nest — weeks 5–6 put a *Music/Space* curriculum inside
  a *Water* world. The reframe that resolves the everyday confusion: they're the
  **two layers of skin** (2026-06-07) — the block is the immersive WORLD, the
  week is the curriculum FOCUS — so no surface should show both as "World of X."
  The deeper content-merge (one canonical journey) is an **open decision** for
  the user. Full season operating model + the acceptance contract at the season
  footprint live in **[PROGRAM.md](PROGRAM.md)**. (Threads: THE_DAY.md is the
  day; this is the season; the missing in-app **season hub** is the counterpart
  surface, being built.)
  - **2026-06-09 (resolved + built).** The user chose **ten weekly worlds** as
    canonical ("a new world every week"). `world_blocks.json` was restructured
    from 5 fortnight blocks into **10 weekly worlds aligned 1:1 with
    `ten_worlds`** (Me · Stories · Nature · Water · Music · Space · Dreams ·
    Time · Feelings · Us) — harvesting the prototype's content for the 7 worlds
    it covered and authoring three fresh (Stories / Music / Time, the user's to
    refine). The seam is closed: `block.week == world.week`, one
    `seasonPositionProvider`. The **season hub** shipped at `/program`. Five
    zoom levels now (the fortnight collapsed into the week).
- **2026-06-14** — **A world's bible is a living CONSTITUTION, not a script —
  "add a rule" makes the community its co-author.** In the user's words:
  *"this whole app is really about systems, coordinations, and proximity-based
  utility… when we create a world, what do we need to start thinking from the
  beginning to create its own 'bible'… imagination, pretend… and 'add a rule'
  mechanic, treating the app as community-based."* Today `world_rules.dart`
  ships **3 authored, verb-tagged rules per world** (Water: *"take the shape of
  whatever holds you"* …) — the FOUNDING seed of the bible. The dream turns the
  bible from shipped-content into a **living document the community AMENDS**: an
  **"add a rule"** mechanic where a room / crew / kid co-authors the world's
  law. The leap is from a world you VISIT to one you BELONG to — and the act of
  writing the rules together **is the lesson** (systems are made by people and
  can be changed by people → the 2026-06-13 "democratizing the systems to
  think" reframe, made literal). What to settle **from the beginning** so the
  data model can hold a living bible: (1) **provenance** — every added rule
  knows who / when / which world it was born in (that's what makes it *theirs*);
  (2) **scope** — world / room / crew / kid / program (maps to Space / Group /
  Subject); (3) **ratification** — who holds the pen (lean: kids propose → the
  room votes via the present engine #18 → staff ratify — kid-voice with a safety
  rail); (4) **founding vs amended** — the shipped 3 are immutable premise; the
  community adds *beside* them ("the world's rules + our rules"); (5)
  **lifespan** — versioned / retired, never deleted; "the rules we made this
  summer" lands as a page in the Book (#1); (6) **proximity-surfacing** — a rule
  appears **where/when it's lived** (world rules on the morning cast, room rules
  in the room, a kid's vow on the me-screen), never a list to memorize. This
  ties the whole thesis: the bible is the world's **SYSTEM** (laws make it
  actable, not just a theme), adding/ratifying a rule is **COORDINATION** (a
  community agreeing how to play), and surfacing by where-you-are is
  **PROXIMITY-BASED UTILITY**. (Threads: dream #5 make-our-own-rules + the
  shipped anonymous board; #13 one-engine-many-worlds; #16 missions; #18
  present/control as both the vote AND the surface; WORLD.md's "Rules" facet +
  `world_rules.dart`; the 2026-06-13 democratizing-systems reframe. **Open
  forks:** who holds the pen; which scopes ship v1; can the founding 3 ever be
  amended; the exact proximity surfaces.)
- **2026-06-14 (cont.)** — **The pen is the phone, in the room, live —
  present/control IS the system of how we learn.** Answering "who holds the
  pen?", in the user's words: *"a staff holds the phone up to control the tv
  with me engaging and guiding the experience, this is going to be the system
  of how we learn when we give it time…"* The governance fork **dissolves**:
  rules aren't co-authored in a form or a settings screen — they're made in the
  **live present/control moment** (#14/#18), with a human GUIDING. The triad is
  the unit of learning: **staff + phone (the conductor's baton) + TV (the shared
  attention)**, the teacher engaging the room. The app is the **instrument, not
  the instructor** — *"the room does the teaching; the app does the
  remembering"* (2026-06-08). Consequence for **"add a rule"**: it's a **live
  beat**, not a feature — the teacher, phone in hand, proposes → the room
  answers out loud / hands up (the present-engine poll, already shipped) → tap
  to ratify → it lands BIG on the TV → it's canon → into the bible + the Book.
  It reuses the live spine end-to-end (This-or-That present/control), with no
  separate rules-admin surface. *"When we give it time"* = it's **cumulative**:
  the same loop, daily, compounds a world's bible + each kid's book over the
  season — a long-arc pedagogy, not a demo. The reframe this forces on the whole
  app: if the live session is THE system, then every world-facet + primitive
  wants a **beat the teacher can play from the phone** — highlight-a-word ·
  spell-for-me · reveal · vote · **add-a-rule** … — the instrument's *keys*
  (extends the 2026-06-13 "phone as live classroom instrument" dream). Threads:
  #14/#18 present-control; #5 make-our-own-rules; the 2026-06-08 acceptance
  contract (*"under 12 minutes, all teacher-facing"* — the app stays nearly
  silent); the cumulative paper → Book arc.
- **2026-06-14 (cont.)** — **Stopwatch, not Pomodoro — then a REQUIRED
  reflection: growth + accountability made visible.** In the user's words:
  *"instead of pomodoro, we use stopwatch, then we require a reflection from
  user… this is growth and accountability visible."* The swap is philosophical:
  **Pomodoro is a box imposed on you** (a fixed countdown that says "stop"
  wherever you are — external structure, productivity-optimization); **a
  stopwatch is the honest measure of what actually happened** (open-ended, you
  stop when the work is done, it records the *truth* of the effort). On-brand to
  the core: the app doesn't impose structure (the compliance-ledger move it was
  built to invert) — it meets reality and *remembers* it. The **required
  reflection turns the number into meaning**: time alone is a quantity; the
  reflection is "what did this become." Required = **accountability** (you
  account for the time, not just clock it); accumulated = **growth visible** (the
  reflections + times stack into a record you can SEE). In the primitives: this
  is **Timer** (the count-UP variant) + **Question/Reflect** (the prompt on stop)
  + maybe **Scale** ("how did it go?") — the **Pace** beat of the live keyboard
  (2026-06-14), reframed from countdown to stopwatch+reflect, feeding the **Book**
  (#1) / character sheet / staff runbook (that's the "visible"). **The guardrail
  that keeps it from rotting:** accountability here is **to yourself** — your own
  visible growth trend, *never* a ranking, leaderboard, or comparison (that would
  betray the no-punishment vow #4/#11; "accountability" must not become
  surveillance). **Open forks:** who reflects (kid daily → Book / staff block →
  runbook / both — likely both, same atom, different surface); what the
  reflection IS (a sentence / **voice or a tap-a-face Scale for the no-typing
  4–6s** / a drawing / a photo of the paper); when it's required (every stop, or
  only past a threshold so it's meaningful, not nagging); visible to whom (self
  always; room / family / director — all, layered). Threads: the 11 primitives
  (Timer + Question + Scale); the Pace beat; #1 the Book; #16 missions/dailies
  ("age = dailies"); #4/#11 no-punishment.
- **2026-06-14 (cont.)** — **The CALM look IS the brand: one left edge,
  flush-left, flat — everywhere, no exceptions.** In the user's words: *"the
  widgets you showed me in show_widget is how i like the app to look like.. the
  one edge, the flush-left… to all.. it is our brand."* The felt clutter was
  TWO things — boxiness AND indentation/centering. The brand answer, now law:
  (1) **one left edge** — every header / title / subtitle starts at the same x;
  hierarchy comes from type weight + whitespace, never from indentation or
  centering (the login wordmark is the one hero-centering exception); (2)
  **hang the chrome** — icons / avatars / dots live in a gutter to the LEFT of
  that edge, never pushing the text in; (3) **right-align the meta** — counts /
  times / badges on one right edge; (4) **flat** — no boxes; neutral cards
  become flush rows / flat hairline surfaces, while SIGNAL cards (the "Right
  now" lead, error banners, world accents) keep their tint so they pop against
  the calm. Lineage (the references the user blessed): **Linear's 2026 "calmer
  interface"** (recede-don't-compete, fewer icons / separators, structure
  without boxes), **iA Writer / Things 3** (flush-left calm), the **Swiss /
  International Typographic Style** (flush-left ragged-right as the *honest*
  alignment; hierarchy via type + grid). SHIPPED: the Calm display setting
  (default on; toggle-off reverts), `FeatureCard` → flush one-edge rows, an
  app-wide `flatCardTheme` (every raw Card flat). REMAINING for TOTAL
  consistency: convert the hand-rolled custom layouts (Today's rich cards) into
  flush rows. This is the **sharpened, enforced form of dream #10**
  (breathable / one visual language) — docs/THEME_ADHERENCE.md is the *colour*
  half of the brand law; this is the *layout* half.
- **2026-06-14 (cont.)** — **The app reveals the right tools for the moment —
  context is the navigation.** In the user's words: *"what if the workflow is
  that we set up the time and context and based on that, the tools reveal
  themselves… if i'm in a time where there's an activity in a room, it only
  shows what i can do during that time… if it's a field trip, i can checkout
  vehicles."* The antidote to feature sprawl is NOT fewer features, or even
  calmer screens — it's features that **appear only in their moment**. The home
  surface computes the current **context** and offers the small set of moves
  that matter right now; everything else recedes into the omnibox (the
  always-there escape hatch). This is "proximity-based utility" made literal and
  the sharpest expression of *"the app is the instrument, not the instructor"*:
  the room + the clock play the instrument; the app hands you the control for
  the current beat. **Context = five dimensions:** *time* (day phase + the
  current schedule block), *place* (your room / cohort), *block kind* (activity
  vs field trip vs break vs meal vs outdoor…), *role* (capability), *state*
  (unmarked attendance, a flagged kid, a pending pickup). **Reveal logic** maps
  `(blockKind × phase × role)` → an ordered list of Verbs, each
  capability-gated — a declarative, testable table. Examples: an **activity
  block** → run the session · take/edit attendance · log an observation · the
  wall question · the stopwatch reflection; a **field trip** → check out a
  vehicle · trip roster + headcount · "left / back" status · trip kids'
  emergency contacts; **pickup phase** → the release board · who's still here ·
  the late-pickup timer; **arrival** → who's not checked in · late alerts (and
  for a director, the cross-room version). The field-trip → vehicles case is the
  killer demo: vehicles are useless 95% of the time (drawer clutter) and
  essential during a trip — context turns a buried feature into a just-in-time
  one, which **generalises to the whole long tail** (every buried feature has a
  moment where it's the star). **The seed already exists:** `dayPhaseProvider`
  (arrival/program/pickup/closed), `currentBlockProvider` / `NowNextStrip`, and
  the Today `_RightNowCard` already does a primitive version (arrival →
  check-in, program → run the day, pickup → roster). This dream *elevates that
  one lead card into the whole home surface* — a "now-playing cockpit." **Open
  design questions:** (1) how the app KNOWS context — inferred (clock + schedule
  + your room assignment) with a one-tap override, not a manual setup each time;
  real proximity (door QR / beacon / geofence) is a later layer; (2) reveal
  GENEROUSLY, never cage — show the block's tools + the always-relevant few,
  keep the omnibox as the full palette, because a wrong inference that *hides*
  the tool you need is the failure mode; (3) it's **Today evolved**, not a new
  screen — the one-edge styling work is the visual foundation, this is the
  *information* foundation. (Ties: the proximity-utility / instrument dream; the
  eleven PRIMITIVES — each contextual tool is a Verb; the schedule = the
  "setlist", each block a "scene" with its own palette, echoing the
  live-instrument / keyboard-of-beats dream.)

- **2026-06-15** — **The app is a clock that knows your kids — progressive
  disclosure through time.** The full, worked shape of the 2026-06-14
  "context is the navigation" dream, taken to its end: not a lead card on top
  of a Today screen, but **the whole surface IS the clock.** In the user's
  words: *"The app shows one thing at a time. The right thing at the right
  time. Nothing else exists until you need it… the screen follows the clock.
  At 9:10 you see the verb picker. At 1:00 you see activities. At 2:45 you see
  the reveal. At 3:00 you see parent messages. You never navigate."* The
  governing metaphor: ***the ocean has the surface, the shallows, and the deep
  — you stand on the shore and see the surface; that's enough; you can wade in,
  you can dive, but you never HAVE to. The app is an ocean with a beautiful
  shore.***

  **Three layers, revealed by clock / week / curiosity:**
  - **LAYER 1 — THE SURFACE** (what you see without trying): ONE card, no
    tabs, no nav, that *changes automatically by time of day.* The beats:
    **9:00 Good Morning** (date · day-of-journey · this week's world · 10
    names, tap-a-name → mood weather) → **9:10 Verb Pick** (name selector + 12
    verb emojis; 3 taps/kid; a whisper-faint world emoji appears as you pick =
    the teacher sees the reveal first) → **9:15–12:30 "Now"** (the current
    schedule block as one card + progress bar + a one-sentence world-matched
    activity suggestion; below, 10 kid circles each showing their 3 verbs, tap
    → mini-card + quick note) → **1:00 Verb Hour** (the Now card, suggestions
    expanded to 3–4 activities matched to today's picks) → **2:45 Reveal**
    (dark, dramatic; tap a kid → 3 verbs pulse in → the world emoji GLOWS to
    center → *"Leah was 🐬 Dolphin today"*; swipe through 10, ~5 sec each) →
    **3:00 Send** (after kids leave; a per-kid pre-written parent message — the
    ONLY thing to fill is one observation sentence — then COPY → paste). *"The
    'Now' screen is where the teacher lives 80% of the day… glanceable in 2
    seconds, actionable in 5, closeable in 1."*
  - **LAYER 2 — THE SHALLOWS** (pull DOWN to reveal — a *curiosity* bar, NOT a
    nav bar; most days you never touch it): 📋 Today · 👤 Kids (character
    sheets, for Friday reflections + conferences, never mid-day) · 📖
    Activities (browse by world or verb) · 🌟 Collection (the room's
    worlds-visited — observational, not comparative) · 📊 Patterns (the data
    view — Friday/Sunday prep, never during the day).
  - **LAYER 3 — THE DEEP** (a separate **"conductor" web dashboard on a
    laptop**, not the phone — touched once a week): weekly planning, monthly
    reports, the **end-of-summer auto-generated per-child report → PDF.** *"The
    app lives on Layer 1. The dashboard lives on Layer 3. They never compete
    for attention."*

  **Continuity is the app's job; today is the teacher's.** Every RPG system
  stays continuous with near-zero management: *avatar* prompted each new-world
  Monday (5 prompts/50 days), *title* each Monday (Declaration Day), *level* =
  the auto-incrementing journey number, *spells* = auto-suggested
  word-of-the-day, *missions* = auto-suggested (completion implicit in filled
  verb dots), *collection* auto-fills from the reveal (the reveal IS the data
  entry), *weather* = 3 prompts/day, *lore/Wall* = a Friday "photograph the
  Wall" → Wall Archive. *Allies + inventory stay analog — the physical journal
  IS the inventory.*

  **The laws:** **one-thumb** (tap/swipe only — the other hand holds a crayon,
  a kid, a coffee; the sole typed input is one parent-message sentence) ·
  **the emotional arc matches the room** (calm 9:00 → warm 9:15 → utilitarian
  midday → **dark/glowing reveal, the app's finest moment** → quiet/reflective
  send) · a hard **NOT list**: no notifications during activities, no
  gamification beyond the collection grid, no kid-facing screens by default (a
  kid build, if any, is exactly 3 screens: pick / dots / reveal), no social
  features, **no AI in v1** (verb→world is a lookup table; suggestions are a
  filtered tagged library; the message is a template). ***"The app is just a
  filing cabinet that knows what time it is."*** The acceptance test: *"If the
  teacher is thinking about the app during Verb Hour, the app failed. If the
  reveal makes a kid gasp, it succeeded."*
  - **Status:** vision → **partly built, needs unification.** The pieces exist
    as separate, navigated surfaces; the dream fuses them into ONE clock-driven
    surface. Shipped toward it: the **contextual lead / context pill** (Today's
    `_RightNowCard` + `contextLeadProvider` — the 2026-06-14 seed),
    `dayPhaseProvider` + `liveBlockProvider` (the clock), the **present/beat
    spine = the Reveal** (`BeatPresenter`, growth arc), **Send** (welcome PDF +
    messages + `buildParentMessage`), **Verb Pick** (`action_words_kid_screen`),
    mood weather, the `/program` season hub. The GAP is the **frame**: today
    these are reached by navigation; the dream makes the *surface itself* the
    clock (an auto-advancing single card) with nav demoted to **pull-down
    curiosity**, plus the **Layer-3 conductor web dashboard** (doesn't exist).
  - **Threads:** the DIRECT continuation of the 2026-06-14 "context is the
    navigation" cockpit dream (this is its finished shape); the 2026-06-08
    acceptance contract (*"under 12 minutes, all teacher-facing"* — this is
    HOW); #10 breathable / one-language; #14/#18 present-control = the Reveal;
    #1 the Book = Layer 3's summer report; the eleven primitives (each beat is
    a primitive). **Open forks:** does the surface AUTO-advance by clock or
    offer a one-tap "next beat" (the wrong-inference-hides-the-tool failure
    mode from 2026-06-14 argues for generous + overridable); how an
    off-schedule day (field trip, rain) bends the clock; whether Layer 2 is
    literally a pull-down gesture on mobile.
- **2026-06-18** — **"Do It" — accumulative real-world actions, the
  anti-ephemeral content genre.** In the user's words: *"i want this to be
  instructions of things people could do in real life… kid first as proof,
  eventually for everyone — in meetings, in gatherings, in proximity… games
  are ephemeral data; do it is accumulative."* The sharpest restatement of
  dream #3 (the screen is a launchpad back into the room) and the 2026-06-08
  acceptance contract (*"the room does the teaching; the app does the
  remembering"*): the content that matters isn't trivia you answer in your head
  (riddles / fact-or-fib — **ephemeral**, played and gone) but **a real action
  you get up and DO** (build · find · move · make · ask · help) that leaves
  **persistent, accumulating evidence.** The genre split IS the thesis:
  - **Games = EPHEMERAL.** You play This-or-That, it's session data, it's gone
    — no record that it happened.
  - **Do It = ACCUMULATIVE.** You DO the thing, it produces proof (a photo, a
    count, a note) that PERSISTS and stacks into the child's Book (#1) + a track
    record (#16) over the season. **Doing IS the data entry** (echoes "the
    reveal IS the data entry", 2026-06-15; "writing their answers on paper,
    cumulative", 2026-06-13).

  **Scope: kid-first as the proof case** (afterschool, ages 4–12), but the
  genre is **universal** — real-life doable instructions for **meetings,
  gatherings, anywhere people share proximity** (staff standups, family
  events). This is "proximity-based utility" turned into content. The build: a
  `ContentKind.doIt` bank (the prompts — tagged by verb/world, of-the-day or
  live-presented through the same engine as the games) + an `EntryKind.didIt`
  persistence, so doing one writes an accumulating entry with evidence — the
  part that makes it *stick* instead of *vanish*. (Threads: #1 the Book, #3
  launchpad, #4 host-present/no-typing, #16 missions/real-evidence, the
  2026-06-14 stopwatch+reflection *"accumulated = growth visible"*, the
  content-bank engine #7. **Open forks:** does a room-wide Do-It accrue
  per-child or per-room (likely both, scoped like observations)? what counts as
  evidence per verb — a photo (build/make), a count (find/help), a name/answer
  (ask)? when does it surface for adults — same deck, meeting-tagged, or a
  parallel "gathering" pack?)
- **2026-06-19** — **Heroes — kids build a make-believe self, one piece at a
  time.** In the user's words: *"they'll draw something, and they'll name it…
  [Name] of [From]… an [animal] and their [super powers]… and their animal
  skins."* A kid-mode creative activity where each child assembles an
  **alter-ego**: pick an **animal** + a **skin** (variant look) → give it
  **super powers** → earn a title in the **"[Name] of [From]"** form (Luna of
  the Willow Woods) → **draw it and name the drawing** ("Sky-jumper"). The
  output is a **Hero card** — a keepsake, not a quiz. This is the *creative*
  twin of "Do It": where Do It is a real action that leaves evidence, Heroes is
  an *imaginative* act that leaves an artifact — and both **accumulate** (a
  child's hero can grow over the term, feeding the Book #1 + the showcase /
  growth-arc #16). Echoes the existing Draw-Yourself + character-sheet world,
  generalized from "draw *you*" to "invent *who you could be*". (Threads: #1 the
  Book, #4 host-present/kid-mode no-typing, #16 showcase. **Open forks:** are
  the four pieces one stitched "build-a-hero" flow or four à-la-carte
  activities (likely both — a flow that also stands alone per piece)? does the
  Hero persist as one evolving card per child, or a new one each session? is the
  animal/skin/power catalog program-fixed, director-authored, or kid-freeform
  (type-your-own)? where does it live for family — a sent-home Hero card?)
- **2026-06-19** — **Routines — the room's rhythm, made kid-legible (and
  playful).** In the user's words: *"routines… what do we do at 9? sing a song,
  practice for the summer showcase, PE, brain breaks… 'My brain is breaking…',
  the workout for your experience/brain?"* The schedule already exists
  staff-side; this is the **child-facing** read of it — a glanceable "**what do
  we do now / at 9?**" rhythm the room internalizes, with **named, recurring,
  warmly-voiced blocks** (sing a song, showcase practice, PE = "the workout for
  your body", **brain breaks = "the workout for your brain"** — the pun *"my
  brain is breaking"* is the kid-facing voice, not a bug). The dream: a routine
  isn't a grid to a 6-year-old — it's a **rhythm they can predict and belong
  to.** Reframes Brain Breaks from "a deck of fillers" into **"the
  brain/experience workout"** — exercise for the mind, named as such. (Threads:
  #4 host-present, the Schedule + day-templates feature it re-skins, #3 the
  screen points back at what the room does together. **Open forks:** is this a
  new kid-mode surface or a kid view layered on the existing schedule? do the
  playful sublabels ("the workout for your brain") live on each activity
  template, or a routine-only voice layer? does "what do we do at 9?" answer
  from the live schedule, a named routine template, or both? is the showcase a
  first-class recurring routine block that compiles practice → the summer show?)
- **2026-06-19** — **The big download: a world of magic, no phones, visible
  growth, document the now.** A flood of the soul of the thing, in the user's
  words. It coheres into one philosophy with many limbs — capture all of it:

  - **No phones, all proximity — the game-show model.** *"a parent is the only
    one who has the phone, the child never uses it… a game show — hosts,
    players, audience. no social media, all in proximity."* The device belongs
    to the adult (staff host / parent at home); the child never touches a
    screen. Interaction is a **game show**: staff = host, kids = players, the
    room = audience. This is the deepest design constraint and the answer to
    why every kid surface is host-presented / paper-based, not a kid holding a
    phone. (Crystallizes dream #4 "host-present, no kid typing" into a worldview.)

  - **"Who are you to me?" — the relational core.** AJ's revelation: *"who are
    you to me?"* The one thing worth knowing. Identity is **relational**, in
    proximity — not a profile, a relationship. The social question the whole
    app orbits.

  - **Future self + imaginative identity.** *"what if you're a whale. or an
    octopus… every day we think of things — what do we wanna be when we grow
    up? what kind of person do i want to be? my future me."* A daily reflective
    identity prompt — who am I, who am I becoming. Direct extension of **Heroes**
    (the animal alter-ego) toward "my future me."

  - **The container: "A World of Magic" / "A Summer of Magic" — a spellbook.**
    *"a summer of magic, or a world of magic… where we only do one thing a week,
    a weekly project… we get dailies, and we get weeklies, and showcase… all
    that RPG as utility and for good."* The cadence is **dailies → weeklies →
    showcase**, wrapped in a magic theme (a spellbook). **RPG-as-utility**: the
    game shell serves real growth, "for good." This is a content pack + cadence
    on the EXISTING worlds / journey / week-engine / Book system, not a new
    engine — reskin "world" as "magic," add the daily/weekly/showcase rhythm.

  - **The daily ritual: Question / Quote / Mission of the Day → a response.**
    *"question of the day, quote of the day, mission of the day — the content in
    sequence with story arc… a question of the day always followed by drawing or
    interpretation — a sound, a sentence, a drawing… these are going to be the
    things they'll write in their books — their learning with intentionality."*
    The SPINE. Each day: a Question, a Quote, a Mission — sequenced along a story
    arc — and every prompt is **answered with a response** (a sound, a sentence,
    a drawing, an interpretation). The responses ARE what fills the child's Book.
    *"what will you invent…"* is one such question. (Partly exists — wall
    "Question of the Day," Action Words word-of-day — this unifies them into one
    sequenced, response-capturing daily.)

  - **Document the now — the transcript is the record.** *"we'll be someone, and
    if that's so… document the now, there ain't no other way. one day, the
    transcript is my quotes."* Growth isn't graded, it's **documented**. The
    accumulating record of quotes / responses / moments over time IS the
    portfolio (the Book #1, the showcase #16). *"i don't want ABCD grades, i
    want visible growth."* — the explicit rejection of letter grades for a
    visible, accumulating arc.

  - **Offline-first, on paper — doing is the data.** *"must be offline first —
    like writing the numbers 1-10 on paper, and writing math answers, or trivia
    answers."* The doing happens on **paper**, captured (photographed) — not
    typed into a kid device. Reaffirms the "Do It" / work-sample / snap-the-paper
    model as the default for every answer surface.

  - **"What to do instead" — the calm agreements list.** *"there are no phones,
    and there's now 'what to do instead?' — what to do in every scenario, when
    we're mad, when we're bored, when we're anxious… collective memory, rules,
    agreement, common ground… not noise, just a list."* A calm, shared reference
    of agreements + what-to-do-instead per feeling (mad / bored / anxious). The
    room's **common ground**, co-held. Extends the **Toolkit** (cool-down et al.)
    from staff crisis-cards toward a kid-legible, collective "what we do instead."

  - **Homework, both sides.** Parent homework: *"review the routine."* Kid
    homework: *"bring in something that they see on TV to bring to class — parents
    approval, and sent."* A parent-mediated loop (the parent holds the phone):
    the kid brings something from the world (TV), the parent approves + sends it
    in, it surfaces to the room. Family-side + class-side.

  - **Activities named:** *"draw outside — clipboard, paper, pencil… really know
    what's seeing and looking means"* (observational outdoor drawing — seeing vs
    looking); *"before we close our eyes, why are we closing them — we're
    imagining… we're catching up"* (a framed close-your-eyes imagine/reset break);
    *"a list of a bunch more brain breaks that people are on trend — YouTube,
    TikTok"* (more deck content, trend-aware but offline-adapted).

  - **Public development — teaching in public.** *"staff has professional
    development, people have personal development, but there's also a
    p---development which [is] accountability and transparency — teaching in
    public — your own curriculum, your own way of thinking."* A third
    development axis beyond professional + personal: **public** — building your
    own curriculum / thinking in the open, with accountability + transparency.
    (A future surface; ties to "document the now.")

  **The through-line:** no phones for kids → everything host-presented in
  proximity → a magic-themed cadence of dailies/weeklies/showcase → every prompt
  answered on paper, captured → the accumulating record (quotes, responses,
  moments) IS visible growth, not grades → identity ("who are you to me?", "my
  future me") is the recurring question. Most of the machinery exists (Book,
  worlds/journey, Action Words, Toolkit, Heroes, Reflections, showcase, Do It);
  this download is the **soul that unifies them** + a handful of new limbs (the
  sequenced daily ritual, the "what to do instead" list, the TV-homework loop,
  draw-outside, public development). **Open forks:** which limb first — the daily
  Question/Quote/Mission ritual (the spine) vs the "what to do instead" calm list
  vs the magic re-skin of worlds vs the TV-homework loop? Is "A World of Magic" a
  new content pack or a re-theme of the live worlds engine?
- **2026-06-19** — **Potions + the garden: hands in the real world; happiness is
  here.** In the user's words: *"potions, we're creating our own potions, we'll
  go to the garden and smell the plants and water them… we'll take turns… we'll
  be gardeners… we'll practice… and every day, what we learn from today is
  shared with parents… community… drawing, and dialogue… what is happiness? it
  is here? the story arc."* The magic theme made REAL and SENSORY:
  - **Potions + gardening as the flagship Do-It.** Making potions (mixing
    petals, water, scents), tending a garden (smell the plants, water them, take
    turns, *be* gardeners, *practice* daily). Tactile, in-proximity, role-play,
    repeated — the perfect marriage of "Do It" (real action, on paper/in the
    world, leaves evidence) and "A World of Magic" (the spellbook frame). Potions
    ARE the spells; the garden IS the world. (Plugs into the live Do-It bank +
    the Daily's mission + the Spellbook.)
  - **Drawing AND dialogue** — the two response modes, named again. Every prompt
    answered by *making* (a drawing) OR *talking* (dialogue). Reinforces the
    Daily-response contract (a sound / sentence / drawing) and the discussion
    activities.
  - **"What is happiness? Is it here?"** — the deepest Question of the Day, tied
    to the story arc. Presence: happiness is *here*, now, in the smelling and
    watering and taking-turns — not a destination. A reflective prompt that
    belongs in the Daily's question bank, and the kind of question the whole arc
    keeps circling.
  - **Daily share to parents → community.** *"every day, what we learn from
    today is shared with parents… community."* The accumulating record
    (#documenting-the-now) doesn't just sit in the Book — a **daily digest of
    what the room learned/did/made goes home to parents**, and the sum of those
    is the community's shared memory. This is the missing FAMILY-FACING half of
    the Daily: today's question + responses + mission + potions → a parent recap.
    (The real new feature here; the rest is content. Reuses the Daily entries +
    the family lens.) **Open forks:** is the daily parent recap auto-composed
    from the day's `daily_response` + `did_it` entries, or staff-curated? push
    (a notification / message) or pull (a family-side "Today" card)? per-child or
    whole-room? Is "community" a future shared/public layer (cf. "teaching in
    public") or just every parent seeing their child's day?

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
