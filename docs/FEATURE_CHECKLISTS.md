# Feature completeness checklists — "what could this be?"

A standing practice (requested 2026-06-04): for any feature, a checklist of
what a **complete, best-in-class** version could include — grounded in three
sources, not just opinion:

- **Users** — the personas' real jobs-to-be-done (docs/PERSONAS.md + the
  10-persona working set in FEATURES.md). What the people actually need.
- **Standards** — the table stakes for the category. What every comparable
  product has, so the absence reads as "unfinished."
- **Trends** — what best-in-class / modern versions do. The differentiators
  people switch for.

Status key: ✅ shipped · ◐ partial · ⬜ not yet · 💭 idea / vision.

**This is a menu, not a commitment** — the point is to choose deliberately
instead of guessing. New per-feature checklists get added here as we touch
each one.

## The lens (every checklist covers these)
1. **Core jobs** — does it do the primary job well, for each persona?
2. **The four states** — loading / empty / error / data (docs/SCREEN_RUBRIC.md).
3. **Standards / table stakes** — the category baseline.
4. **Trends / delight** — what makes it best-in-class.
5. **Accessibility & inclusion** — a11y, i18n, age-appropriateness.
6. **Resilience & edge cases** — offline, errors, spam, weird input.
7. **Outcome** — does the work produce something durable (the app's spine)?

---

## Games — brain breaks / present-control
**Category peers:** Kahoot · Gimkit · Blooket · Quizizz · Jackbox · Baamboozle.
**Users:** a teacher driving a room of kids (Maya / Coach Sam / Brianna); the
kids themselves (Ava).

### Core jobs
- ✅ Run a game with the room (present + control over Realtime)
- ✅ One place to join, program-wide (Today live banner + `/join`)
- ✅ Fresh content on "play again" (never-repeat; the reseed)
- ⬜ **Continue / "keep going"** — extend the current round with MORE fresh
  questions without resetting the score *(your ask — distinct from replay)*
- ⬜ **End-of-round screen** — tally/score + a celebration + clear next
  actions: Play again · Switch game · Done
- ⬜ **Skip / swap a dud** — replace an awkward generated item mid-round

### Present / display (it lives on a big screen)
- ◐ Fullscreen present — in the LIVE header only; ⬜ not on single-device, and
  ⬜ no obvious **exit** from fullscreen *(your ask)*
- ⬜ Room-readable type (legible from the back row) / a "bigger" toggle
- ✅ Live join code + presence ("12 joined")
- ⬜ Persistent join QR for late-comers

### Teacher control
- ⬜ Size the round (5 / 10 / 15) + an easier↔harder / age dial
- ⬜ Pause / resume
- ✅ Back / re-show a question
- ⬜ Mute / sound toggle

### Engagement & feel (the Kahoot/Blooket bar)
- ⬜ Sound + haptics + a light music bed
- ⬜ Optional per-question timer
- ⬜ Score / streak / a celebration beat at the end
- 💭 Room reactions (emoji from every phone)
- 💭 Team mode

### Content quality (our combinatorial promise)
- ✅ Combinatorial freshness (1M+ instances, no AI in app)
- ⬜ Thumbs-down to REMOVE a bad item (a never-show list)
- ⬜ Report / flag content
- ◐ Age-band tuning (some content tuned; not a teacher-facing control)
- 💭 Teacher-authored questions (ties to the thinking-tools contributor vision)

### Accessibility & inclusion
- ◐ Voiceover for pre-readers (TTS exists in survey-take; ⬜ not in games)
- ⬜ Contrast / color-not-alone audit on stages (SCREEN_RUBRIC E5/E6)
- ⬜ Text-scale-safe stages (200%)
- ⬜ Spanish / i18n (Lauren)

### Resilience & edge cases
- ✅ Live disconnect/reconnect resync (presenter rebroadcasts canonical state)
- ✅ Offline single-device (content bank is local; no network needed)
- ◐ Kid-mode lock (mechanism exists; games not yet kid-locked)
- ⬜ Duplicate / spam-join handling

### Outcome (the app's spine)
- ✅ Capture evidence from a game (CaptureSpec → content_items / entries)
- 💭 Save a round's highlights to the growth book / showcase

### Recommended build order
1. **End-of-round screen + Continue/Keep-going** (both your asks live here).
2. **Fullscreen on single-device + a clear exit** (your ask).
3. **Skip-a-dud** + a sound / haptics / timer pass.
4. Size-the-round.

---

## Games — per-game depth (brainstorm 2026-06-04)

Two axes beyond the cross-cutting QoL: **tune it** (controls so a teacher
shapes the game to the time / group / topic) and **keep it** (artifacts so a
round produces something savable, printable, or shareable). Today most games
have hidden knobs and produce nothing durable.

### The two structural unlocks (build these once, every game inherits them)

1. **A game SETTINGS contract.** `GameDefinition` optionally declares tunable
   params (a tiny schema: numeric ranges, on/off toggles, a topic multi-pick,
   a count, a difficulty preset). The runner renders them as a quick pre-game
   sheet and threads the chosen values into `initialState`. Math's min/max and
   mechanics, This-or-That's topics, Letter Words' letters — all become
   first-class controls instead of hardcoded constants. (Generalizes the
   "size the round / difficulty" checklist item.)
2. **A game ARTIFACT contract.** `GameDefinition` optionally produces a
   keepable from a finished round — an image, a text, a list. The framework
   then routes it to: **save to history** (a per-kid / per-class log via
   `entries` / `content_items`), **print** (straight into the poster/PDF
   engine we just built), **share to family** (the family lens), or the
   **growth-story / showcase** (VISION). Pattern → a printable poster is the
   poster tool earning its keep; a built Story → a take-home page.

### Per-game (tune it · keep it)

| Game | Tune it (controls) | Keep it (artifact) |
|---|---|---|
| **Math** | number range (min/max), operations (+ − × ÷), which mechanics (choose / type / sequence / true-false), question count, age preset | a **printable worksheet** of the round (do it on paper); score → history |
| **This-or-That** | which themes/topics, serious ↔ silly, rounds | "our class prefers…" results card → save / print |
| **Story Starters** | which slots, genre (adventure / funny / mystery), length | the **built story** → printable page, growth book, story-of-the-day |
| **Letter Words** | which letters (or one), categories, timer | the class's **word list** → vocab sheet (print), history |
| **Rhyme Time** | seed words / theme, difficulty | the rhyme list → print / save |
| **Riddles** | topic, difficulty, count | riddle-of-the-day to take home |
| **Fact or Fib** | topic, difficulty, count | the true facts learned → save |
| **As-If / Charades** | prompt category (animals / jobs / feelings), age, count | **photo / video** of the act (capture) → family |
| **Discussions** | topic + age band, depth | discussion notes → an observation / entry |
| **Pattern** | symmetry (mirror / rotate / kaleidoscope), repeat, grid size, colors | **the pattern image** → **print BIG (poster)**, history, family, showcase |
| **Photo Studio** | prompt / theme | the photo → kid timeline, family |
| **Poll** | the options (teacher-authored), anonymous on/off | result chart → save / print |
| **Spotlight (Picker)** | the list / roster, fair "no-repeat until all picked" | who-got-picked log |
| **Cues / Now-Next** | which signals / the schedule source | (utility — no artifact) |

### Why this is small to build
Both unlocks ride systems that already exist: the **poster/PDF engine**
(print any visual artifact), **content_items / entries** (history), the
**family lens** (share), and the **content engine** (the settings just
parameterize the generators that already exist). The work is two thin
contracts on `GameDefinition` + one settings sheet + one "save/print this"
router — not per-game one-offs.

---

## Checklists still to write (as we touch each feature)
Poster · Tools · Attendance · Schedule · Observations & Captures · Family lens
· Vehicles · Surveys · Insights · Exports · Live Sessions · Missions · Toolkit.
Produced on request, or when a feature gets a wave.
