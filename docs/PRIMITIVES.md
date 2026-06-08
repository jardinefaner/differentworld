# The primitives — the atoms the system is built from

> Ten atoms named; an eleventh found in the audit. Infinite molecules.
> That's the system.

*(History: the user named ten. The honest audit flagged THE SCALE as a
candidate eleventh; we settled it — promoted, and made real in code as
`Scale` + `ScaleBar`. The list is eleven.)*

The same whether you're 5 or 80, in a classroom or a boardroom, on paper
or on a screen. Every screen, every PDF page, every activity, every
ritual, every tool we've built is a **combination of these eleven**.
Nothing in the system requires anything outside this list.

This doc is the **architecture spine** — a companion to
[VISION.md](VISION.md) (the *why*) and [NAMING.md](NAMING.md) (the
engine-vs-domain contract). VISION says what we're building toward;
PRIMITIVES says what it's all *made of*. Each atom is grounded in the real
code construct it lives as, so the claim is checkable, not poetic.

When you add a feature, ask: **can I express it as a combination of these
atoms?** If yes, it belongs. If it needs an eleventh atom, that's not a
bug — it's a signal worth a conversation (see *Does it hold?* below).

---

## The eleven atoms

| # | Atom | What it is | Reach | Lives in code as |
|---|---|---|---|---|
| 1 | **Verb** | one single-syllable body-action | individual | `kVerbs` (12) — `lib/features/action_words/verbs.dart` |
| 2 | **Three** | the quantity; always three | universal | `kPicksPerDay = 3` — `verbs.dart`; the 3-step bridge; 3-level skills |
| 3 | **Pick** | a free choice, unguided | individual | the verb-pick flow (`EntryKind.actionWords`); the forge's verb-lock |
| 4 | **Reveal** | hidden becomes visible, earned | individual | `resolveWorld` + `WorldMatchKind` + `RevealOverlay` |
| 5 | **Wall** | unfiltered shared surface | **shared** | `EntryKind.wallNote` + `createWallNote` + `/wall` |
| 6 | **Book** | personal accumulation over time | individual | `book_screen.dart` + `summer_book.dart` (`/book/:id`) |
| 7 | **Circle** | everyone faces everyone; ritual | **shared** | the rituals — encoded in the runbook moments + Mood Weather |
| 8 | **Timer** | a finite container for action | universal | `Spell.durationSeconds` (casts) + `skill_measure` (time → data) |
| 9 | **Question** | a sentence with no single answer | **shared** | `ThinkingGame.question` + Wall question + `dinnerQuestion` |
| 10 | **Name** | a word that makes something yours | individual | `emergingTitle` / `setWorldName` / `chosenName` / spells |
| 11 | **Scale** | a position on a bounded continuum | universal | `Scale` + `ScaleBar` — `lib/shared/widgets/scale_bar.dart` |

Five individual (Verb, Pick, Reveal, Book, Name), three shared (Wall,
Circle, Question), three universal (Three, Timer, Scale). The **Wall** is
the only primitive where individual atoms become *shared knowledge*; the
**Book** is its personal mirror. **Scale** is the gauge the others read
on — mood **3/5**, stillness **47s**, journey **Week 6/10**, collection
**4/10**.

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

11. **Scale** — `Scale` + `ScaleBar` (`lib/shared/widgets/scale_bar.dart`). A
    position on a bounded continuum, plus its change. The character sheet
    renders **Collection** (worlds `4/10`) and **Level** (journey `Week 6/10`)
    as explicit `ScaleBar`s; **Mood** is a *discrete* Scale (1–5, drawn as the
    five weather emoji); **Skills** is an *unbounded* Scale (no fixed max — the
    `▲ +13` delta IS the scale's reading). The atom's law: a measure shows
    position AND change, because growth is the point, not the absolute number.

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

No feature in the repo needs a construct outside the eleven.

---

## Does it hold? (the honest audit)

The claim "nothing requires anything outside this list" is checkable, so it
should be checked. Two honest notes:

1. **Circle is barely a code atom.** It's a physical ritual; the app *hosts*
   it (the runbook choreographs it, Mood Weather/Declaration invoke it) but
   doesn't encode it as a structure. That's correct — some primitives are
   social, not software — but it means "the app is made of these atoms" is true
   only if you count one of them as *content the app serves*, not code the app
   runs. Worth saying out loud.

2. **The eleventh atom — SCALE — is settled.** It was the candidate the audit
   raised: a position on a bounded continuum (mood **3/5**, stillness **47s**,
   journey **Week 6/10**, collection **4/10**). The argument that won:
   Timer (#8) is a container for *action with a duration*, but a mood reading
   or a Day-23 marker isn't an action — it's a gauge, and none of the other
   ten cleanly name "a reading on a dial." It's not Pick+Reveal+Book in a
   trench coat: those describe *how a value is set / interpreted / stored*, not
   the value's *being a position on a continuum*. Promoted, and made real:
   `Scale` + `ScaleBar`. The eleven hold.

Everything decomposes cleanly. Eleven atoms, and the system is the
chemistry between them.

---

---

## How the primitives shape the UI/UX

The atoms aren't just *what the system is made of* — each one is a **design
law**. They tell you how a thing must look and behave, regardless of
screen. This is the layer above the composition primitives
(`FeatureCard`, `GlassPanel`, `EmptyState` — see CLAUDE.md): those are the
*widgets*; these are the *rules the widgets must obey*. The
[SCREEN_RUBRIC](SCREEN_RUBRIC.md) checks a screen is *complete*; this
checks it's *true to the atoms*.

1. **Verb → one affordance, everywhere.** A verb is always the same
   tappable object: emoji + word, big, ≥48 dp. The kid's pick, the staff
   skill, the forge, the print card — identical vocabulary. *Law: never
   invent a second way to show a verb.* (Honored: `kVerbs` renders the same
   in every surface.)

2. **Three → never make them hold more than three.** A decision point
   offers many but takes three; chunk everything into threes. *Law: a choice
   surface's working set is ~3. Don't ask a body to hold more.*

3. **Pick → the UI must not guide.** No "recommended," no "you always pick
   CARRY, try a new one," no sort-by-popularity, no nudging default. Free
   choice means a *neutral* surface. *Law: zero optimization pressure on a
   pick — agency is the feature, not a thing to A/B.* (Honored: the pick
   sheet deliberately doesn't editorialize.)

4. **Reveal → withhold, then dramatize.** Never show the outcome before
   it's earned (the world is hidden until the reveal). The reveal is the ONE
   loud moment — glow, full-bleed, immersive. *Law: the payoff is a moment,
   not a label. Defer + dramatize.* (Honored: `RevealOverlay`, the gold glow,
   the deferred fresh-world naming.)

5. **Wall → additive, unranked, unfiltered.** No likes, no sort-by-best, no
   favourite, no teacher curation, nothing removed mid-week. Every answer the
   same size. *Law: shared surfaces never rank or filter — the spread is the
   lesson.*

6. **Book → accumulate, never delete, show the weight.** The journal only
   grows; surface its heft (page count, days). It goes home. *Law:
   personal-history surfaces are append-only and visibly accumulate.* (This
   is why the Book's "quiet/away" weeks render rather than vanish.)

7. **Circle → immersive ritual, chrome off.** Ritual goes full-bleed and
   hides the app chrome; everyone faces one thing. *Law: ritual = chrome-off,
   one focus, no affordances competing for the eye.* (Honored: the immersive
   present/cast/reveal screens, kid-mode hiding the omnibox.)

8. **Timer → shown as shrinking space, calm.** A countdown you can SEE (the
   disk that shrinks), not a number that stresses. *Law: time is shown as
   space running out, not digits ticking up.* (Honored: the spell countdowns.)

9. **Question → open, never graded.** A text field with no validation, no
   right answer, no error state for "wrong." *Law: question inputs have no
   correctness UI — invitation, not test.*

10. **Name → editable + owned, inline.** Anything named is tap-to-rename by
    its owner, in place. *Law: a name is never read-only to the one it
    belongs to.* (Honored: the character sheet's tap-to-edit chosen name.)

11. **Scale → a gauge with the delta.** A bounded measure shows its position
    AND its change — the `▲ +13` is the meaningful half, because growth beats
    the absolute. *Law: never show a measure as a bare number; show where it
    sits and which way it moved.* (Honored now: `ScaleBar`, the skill delta.)

**Cross-cutting:** the eleven also explain the app's *overall* shape — why
it's calm (no Pick pressure, no Question grading, no Scale leaderboards),
why it's offline-first (the Book is paper; the Wall survives the power),
and why a kid surface and a staff surface feel like one system (same Verb
affordance, same Three container, same Reveal beat). When a new screen
feels *off*, it's usually violating an atom's law — a guided pick, a ranked
wall, a graded question, a bare number where a Scale belongs.

---

*Living doc. If a new feature needs an atom not on this list, add it here
with the same grounding (what it is, its reach, the code construct) — or
prove it's a molecule of the existing eleven. Each atom is also a UI law
(above): a screen that obeys the eleven feels like the system; one that
breaks one feels foreign.*
