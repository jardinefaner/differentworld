# The primitives — the atoms the system is built from

> Ten atoms. Infinite molecules. That's the system.

The same whether you're 5 or 80, in a classroom or a boardroom, on paper
or on a screen. Every screen, every PDF page, every activity, every
ritual, every tool we've built is a **combination of these ten**. Nothing
in the system requires anything outside this list.

This doc is the **architecture spine** — a companion to
[VISION.md](VISION.md) (the *why*) and [NAMING.md](NAMING.md) (the
engine-vs-domain contract). VISION says what we're building toward;
PRIMITIVES says what it's all *made of*. Each atom is grounded in the real
code construct it lives as, so the claim is checkable, not poetic.

When you add a feature, ask: **can I express it as a combination of these
atoms?** If yes, it belongs. If it needs an eleventh atom, that's not a
bug — it's a signal worth a conversation (see *Does it hold?* below).

---

## The ten atoms

| # | Atom | What it is | Reach | Lives in code as |
|---|---|---|---|---|
| 1 | **Verb** | one single-syllable body-action | individual | `kVerbs` (12) — `lib/features/action_words/verbs.dart` |
| 2 | **Three** | the quantity; always three | universal | `kPicksPerDay = 3` — `verbs.dart`; the 3-step bridge; 3-level skills |
| 3 | **Pick** | a free choice, unguided | individual | the verb-pick flow (`EntryKind.actionWords`); the forge's verb-lock |
| 4 | **Reveal** | hidden becomes visible, earned | individual | `resolveWorld` + `WorldMatchKind` + `RevealOverlay` |
| 5 | **Wall** | unfiltered shared surface | **shared** | `EntryKind.wallNote` + `createWallNote` + `/wall` |
| 6 | **Book** | personal accumulation over time | individual | `book_screen.dart` + `summer_book.dart` (`/book/:id`) |
| 7 | **Circle** | everyone faces everyone; ritual | **shared** | the rituals — encoded in the runbook moments + Mood Weather |
| 8 | **Timer** | a finite container for action; the measure | universal | `Spell.durationSeconds` (casts) + `skill_measure` (time → data) |
| 9 | **Question** | a sentence with no single answer | **shared** | `ThinkingGame.question` + Wall question + `dinnerQuestion` |
| 10 | **Name** | a word that makes something yours | individual | `emergingTitle` / `setWorldName` / `chosenName` / spells |

Eight individual, three shared (Wall, Circle, Question), three universal
(Three, Timer — and the way they cut across both). The **Wall** is the
only primitive where individual atoms become *shared knowledge*; the
**Book** is its personal mirror.

---

## Each atom, grounded

1. **Verb** — `lib/features/action_words/verbs.dart` → `kVerbs`. Twelve
   prosocial actions a pre-literate child can do with their hands in three
   seconds. The smallest unit; everything else is combinations of verbs.
   Shows up *everywhere*: the morning pick, staff skills (`verb_roles.dart`),
   jobs, missions, the activity forge, the world mapping, the closing game,
   the parent message, the collection, the emerging title.

2. **Three** — `kPicksPerDay = 3`. Small enough to hold, big enough to vary.
   Every combination of three from twelve is a unique identity (the reveal's
   whole premise). Also: the 3-step bridge, 3 staff-skill levels, 3 repair
   questions, 3 weather checks a day, the 3-part Declaration.

3. **Pick** — the act of agency. `EntryKind.actionWords` carries the kid's
   free choice of three; the forge lets you lock a verb (`forgeActivity(...,
   verbId:)`); mood is a pick of 1–5; the title is a chosen name. No pick, no
   system — everything downstream flows from it.

4. **Reveal** — `resolveWorld(picks)` → `WorldMatchKind.fresh|claimed`, shown
   by `RevealOverlay`. The identity emerges *from* the picks (the reversal:
   act, then discover your class). Also the skill delta (`latestSkillValues`
   → "▲ +13"), the avatar evolution, the collection grid, the closing game.

5. **Wall** — `EntryKind.wallNote`, `/wall`. The shared brain of the room:
   questions and answers go up unfiltered; the patterns teach themselves. The
   only *collective* primitive — where individual atoms become shared
   knowledge. Also the word wall, the lore, the showcase.

6. **Book** — `book_screen.dart` (the live journal) + `summer_book.dart` (the
   printable keepsake). The individual's mirror of the Wall: personal,
   accumulating, physical, permanent — it goes home. Everything flows into it
   eventually (avatar, declaration, mood logs, ally page, collection, spells,
   skill trackers).

7. **Circle** — the primitive of *ritual*. The weakest-in-code atom by
   design: it's a physical/social shape, not a data structure. It lives as
   *content* — the runbook moments (Door Greeting, Mood Weather, Closing in
   `staff_runbook.json`) choreograph it; the app supports it but doesn't *own*
   it. Whenever the system needs attention, honesty, or togetherness, it calls
   a circle.

8. **Timer** — `Spell.durationSeconds` (the cast countdowns: FREEZE, MOVE…) +
   the skill measure (`skill_measure` turns "hold still" into 47 seconds of
   data). A finite container for action: urgency without stress, ends things
   before they bore, and — crucially — turns feeling into a number.

9. **Question** — `ThinkingGame.question` (the unanswerable one that goes on
   the Wall), the daily Wall question, the `dinnerQuestion` sent to families
   (`parent_message.dart`). The primitive of *thinking*: without it, it's just
   games; with it, it's philosophy.

10. **Name** — `emergingTitle` (the title that emerges from the verb pattern),
    `setWorldName` (naming a fresh world), `chosenName`, the spells (named
    vocabulary). The primitive of *ownership*: before you name it, it belongs
    to the world; after, it's yours. How you take a piece of the infinite and
    make it yours.

---

## Molecules — every feature decomposed

The proof is that real features are nothing but combinations:

- **The daily app loop** = Pick (3) · Verb (1) · Timer (8) · Reveal (4) · Name (10)
- **The journal / Book** = Book (6) · Name (10) · Pick (3) · Reveal (4)
- **The closing game** = Circle (7) · Verb (1) · Reveal (4) · Name (10) · Timer (8)
- **The Wall** = Wall (5) · Question (9) · Name (10) · Three (2)
- **The parent message** = Name (10) · Verb (1) · Reveal (4) · Question (9)
- **Staff training (the ladder + runbook)** = Pick (3) · Verb (1) · Three (2) · Reveal (4)
- **Big Thinking (play→name→bridge→question)** = Verb-less, but: Timer (8, the 5-min play) · Name (10) · Three (2, the bridge zooms) · Question (9)
- **The activity forge** = Verb (1) · Pick (3, the noun/constraint/time draw) · Timer (8) · Name (10, the composed instruction)
- **The character sheet** = the *aggregate* — every individual atom, accumulated over 50 days, wearing a face

No feature in the repo needs a construct outside the ten.

---

## Does it hold? (the honest audit)

The claim "nothing requires anything outside this list" is checkable, so it
should be checked. Two honest notes:

1. **Circle is barely a code atom.** It's a physical ritual; the app *hosts*
   it (the runbook choreographs it, Mood Weather/Declaration invoke it) but
   doesn't encode it as a structure. That's correct — some primitives are
   social, not software — but it means "the app is made of these ten" is true
   only if you count one of them as *content the app serves*, not code the app
   runs. Worth saying out loud.

2. **The candidate eleventh atom: THE SCALE.** A position on a bounded
   continuum — mood **3/5**, stillness **47s**, **Day 23/50** on the journey
   line, the collection grid's fill. The list folds "the measure" into Timer
   (#8), but Timer is a container for *action with a duration*; a mood reading
   or a Day-23 marker isn't an action — it's a gauge. None of the other nine
   cleanly name "a reading on a dial." It may genuinely be Pick + Reveal +
   Book in a trench coat (you *pick* 1–5; the delta *reveals* growth; it lands
   in the *Book*) — but it shows up often enough (Weather, Skills, Level,
   every progress bar) that whether SCALE is its own atom or a molecule is the
   one open question. Flagging it, not resolving it.

Everything else decomposes cleanly. Ten atoms, and the system is the
chemistry between them.

---

*Living doc. If a new feature needs an atom not on this list, add it here
with the same grounding (what it is, its reach, the code construct) — or
prove it's a molecule of the existing ten.*
