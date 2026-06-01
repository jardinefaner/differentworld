# The activity runtime — the app conducts the experience

**Status:** design approved (2026-05-31). First slice queued (the Math
inverse archetype).
**Origin:** "a SMART class; the time is when you can do it; everything the
user does relates to the activity; the app structures when to click, when
to answer, when to ponder… and I don't like where most of the stuff is —
it's not intuitive."

**The one principle:** the app **conducts the experience in time** — it
does not present a menu of features to go find. At any moment it is in one
of two stances: **Lobby** ("pick an activity") or **Conducted** ("here's
what's happening *now* — do *this*"). During an activity the learner never
navigates; the single action that matters is the only thing on screen. The
cure for "it's not intuitive" is not a better menu — it's *removing the
menu during the experience*.

This is the capstone of the graph work: the **Activity is the central
noun** ([SEMANTIC_GRAPH.md](SEMANTIC_GRAPH.md)); its **phases are
time-triggered rules** (generalizing the rule engine from "on entry
created" to "on phase advance"); **"everything relates to the activity" is
the auto-tag rule** ([LIVE_BLOCK_CONTEXT.md](LIVE_BLOCK_CONTEXT.md)); the
**action buttons are the noun's action vocabulary** (the frame's
`actions`); and the closing **presentation is the frame projected per
student** (the deferred showcase, made concrete).

---

## 1. The primitive

> **Activity** = `{ archetype, phases[], actions[], generator?, presentation? }`
> **Phase** = `{ mode, prompt, pacing, capture }`

- **mode** — the interaction archetype (§2): `click · shoot · answer ·
  create · ponder · vote · present`. Each is a full-screen, kid-mode
  surface — big targets, no chrome, one job.
- **prompt** — what the app *tells* the learner right now ("find a
  shadow", "now delete your worst shot", "make a path to 12 nobody else
  will think of").
- **pacing** — what advances the phase (§3): a teacher tap, a timer,
  per-learner completion, or "non-stop until time's up".
- **capture** — the data this phase produces (a photo, a tap-count, an
  answer, a coined word), auto-tied to `(activity, phase, learner)`.

**CRUD as rhythm.** The create/update/delete verbs aren't buttons buried
in a menu — they're *phases*. A photography activity teaches editing as a
sequence: `create` (shoot) → `update` (pick/improve) → `delete` (cull the
weak ones). The app narrates the verb at the moment it's pedagogically
live.

The runner's whole job: walk the phase list; for each, show the prompt,
enable the right mode + actions, gather activity-tagged data, advance by
the pacing rule. That is the engine. Everything below is content poured
into it.

---

## 2. The interaction modes (the closed set)

A small, fixed vocabulary — like the condition vocabulary in
SEMANTIC_GRAPH, kept deliberately small so the system stays legible.

| Mode | The learner… | Captures | Built on |
|---|---|---|---|
| `click` | taps, fast, repeatedly | tap events / shutter burst | new |
| `shoot` | takes photos to a prompt | photos (Storage path) | face-aligned camera (planned) |
| `answer` | responds to a question | a typed/spoken answer | inline-edit + Deepgram |
| `create` | makes something original | text / drawing / coinage | inline-edit, dictation |
| `ponder` | reflects; no input; timed | nothing (a held beat) | new (a timed still screen) |
| `vote` | ranks the room's creations | a vote tally | new (one-tap, anonymous) |
| `present` | watches a projection | nothing (output phase) | showcase projector |

Modes are full-screen and kid-mode by default (the AppShell strips chrome,
as `survey_take_screen` already does — the closest existing surface to a
runner).

---

## 3. Who holds the baton (pacing)

The biggest structural fork, resolved per-phase rather than globally:

- `teacher` — everyone advances when the teacher taps. **Default for
  group/sync moments** (present, vote reveal, a shared prompt).
- `timer(d)` — the script auto-advances after a duration. Good for
  `ponder` and timed bursts.
- `perLearner` — each learner moves at their own speed; the teacher sees a
  progress strip. **Default for `create` / `answer` / `shoot`.**
- `nonStop(until)` — one long phase that runs until a wall-clock end (the
  Click Game's burst).

The runner is one state machine that supports all four; an activity picks
per phase. **Synchronized (teacher/timer) and independent (perLearner) are
the two runtimes** — the runner must model both from the start, because
retrofitting independent pacing onto a synchronized engine is a rewrite.

---

## 4. The phase-loop templates

Most activities are one of a few loops; an archetype picks a loop and
fills in mode + prompt + generator.

- **Make-and-keep:** `seed → create → share → vote/validate → keep/ponder`
  (Math, Word Invention, most generative subjects).
- **Do-and-cull:** `prompt → do → cull → present` (Photography).
- **Burst:** `ready → burst → reveal` (Click Game).

---

## 5. Every subject, one engine

| Activity | Phase score | Generator | Pacing |
|---|---|---|---|
| **Photography** | ponder("today: shadows") → shoot(rotating prompt) → cull("keep 3, delete the rest") → present(per-student gallery) | — | perLearner shoot; teacher present |
| **Click Game** | ready → click(burst) → reveal | — | nonStop |
| **Math (inverse)** | present("answer is 12") → create("invent questions = 12") → validate+share → ponder("many paths, one place") | target→expressions (local) | perLearner create; teacher reveal |
| **Word Invention** | present("ocean + memory") → create(coin a word + meaning) → gallery → vote → keep("enters the class dictionary") | seed pairs (curated/optional LLM) | perLearner create; teacher vote |
| **Science** | observe → hypothesize → test → record | — | mixed |
| **SEL ("Action Words")** | pick 3 verbs → act through the day → reflect | curated verb bank | perLearner |

Same runner, same data tie, same presentation machinery; only the score
and the generator change.

---

## 6. The two generative ones (worth their own thought)

### Math, inverted — "how many paths to 12?"
Flips math from *find the answer* to *find the ways*, and the learner
**generates**. The room fills with `3×4`, `6+6`, `24÷2`, `15−3`… and they
*see* one destination has many roads. Then: "make a path nobody else
will."

- **No AI needed to be safe.** Arithmetic inverse-generation + validation
  is pure Dart — an expression generator + evaluator. `valid = eval(expr)
  == target` and `novel = not in the room's set` are literally rules in
  the SEMANTIC_GRAPH engine. Offline, zero privacy surface. (An LLM helps
  only for *word-problem* framings, which can be brokered + optional.)
- The ideal **first archetype**: highest pedagogical clarity, lowest AI
  risk, fully offline, exercises the whole make-and-keep loop.

### Word Invention — "all words are invented"
Two seed words → each learner coins one + a meaning → gallery → vote the
most creative → **the winner enters the class dictionary.** Over a term the
cohort builds its own living language — which feeds the showcase/growth
arc. The creation is the learners'; AI is optional seasoning (suggest seed
pairs, an example sentence). Voting is on **words, not people** —
authorship hidden by default → low bullying surface.

---

## 7. The rules (invariants)

- **The activity drives; the learner never navigates.** During a
  conducted phase, exactly one action surface is on screen. No drawer, no
  omnibox, no menu (kid-mode).
- **All capture ties to the activity.** Every datum a phase produces
  carries `(activity_id, phase, subject_id)` at write time — the auto-tag
  rule, generalized. Nothing made during an activity is orphaned.
- **AI is local-first; cloud AI is brokered.** Math generation is
  on-device. Any cloud model (word framings, word-problem prose) goes
  through a Supabase Edge Function — never a master key on the device
  (docs/SECRETS.md). No child identifiers in any AI prompt.
- **Pacing is explicit per phase.** The runner never guesses whether a
  phase is teacher- / timer- / learner-paced; the activity declares it.
- **A learner can't break out of a conducted activity** by accident
  (system-back, etc.). Exit is a deliberate staff gesture (the kid-mode
  exit PIN already exists).
- **Voting is on creations, not authors.** Authorship hidden by default;
  no free-text on a peer's work in v1; teacher can moderate the reveal.
- **The data model reuses what exists.** A run produces `entries`
  (`kind` per phase, `payload` for the answer/coinage/tap-count) tied to
  the activity. Photos ride the Storage path; only the path string syncs.
  The class dictionary + showcase are *projections* of these entries — no
  new heavy schema for the first slices.

---

## 8. The acceptance rubric

**Runner**
- ☐ The runner walks a phase list, exposing exactly one current phase.
- ☐ Each pacing kind advances correctly: teacher tap, timer, per-learner
  completion, non-stop-until.
- ☐ Advancing past the last phase enters `present`; there is always a
  defined end.
- ☐ A conducted activity hides all app chrome (kid-mode) and survives a
  system-back without leaking to staff surfaces.

**Math archetype (first slice)**
- ☐ Generator: given a target + difficulty, produces N distinct valid
  expressions that evaluate to the target.
- ☐ Validator: a learner's expression is judged `valid` (well-formed),
  `equals` (== target), and `novel` (not already in the room's set).
- ☐ Pure / offline / no network; evaluation is deterministic.
- ☐ "valid" + "equals" are expressible as SEMANTIC_GRAPH rules.

**Data + trust**
- ☐ Every capture in a run reads back tied to `(activity, phase, subject)`.
- ☐ A run is resumable: closing mid-activity and reopening returns to the
  current phase (local-first state).
- ☐ Presentation projects only this room's data; no cross-cohort leak.

---

## 9. What this unlocks

- The **showcase/growth arc** — `present` is its first concrete surface;
  the term portfolio is a projection of accumulated run entries.
- The **class dictionary** — Word Invention's kept coinages become a
  living per-cohort artifact.
- **Teacher authoring** — new activities are new phase scores over the
  same modes; no code change (the SEMANTIC_GRAPH "rules as data" promise).
- **The home screen reframed** — Today becomes "what's live / what to
  start," not a feature grid. The IA stops being a menu.

---

## 10. The build seed

**Slice 1 — the Math archetype core (Wave: AR-math).**
- Pure Dart, no UI, fully tested: an expression evaluator, an inverse
  generator (`target → distinct valid expressions`), and a validator
  (`{valid, equals, novel}`). Reuse the SEMANTIC_GRAPH rule engine for the
  `equals`/`valid` checks so the runtime stays one engine.
- A minimal phase-runner state machine (`ActivityRun`: phases, current,
  advance(by pacing)) — pure Dart, tested for all four pacing kinds.
- Proves the conducted loop's logic (present → create → validate → ponder)
  with zero AI and zero network.

**Slice 2 — the kid-mode Math runner screen (follow-up).**
- A full-screen kid-mode surface that drives one Math activity through its
  phases: present the target, accept a coined expression, validate live,
  show the room's variety, ponder. The first *visible* conducted
  experience.

**Slice 3+ — Word Invention + the presentation projector** reuse the same
runner with the `create`/`vote`/`present` modes and the curated seed bank.

If Slice 1 feels right — generation is rich, validation is instant, the
phase loop is clean — the screen, the other archetypes, voting, the class
dictionary, and the showcase are content and surfaces over the same engine.
