# THE DAY — one day, minute by minute

The canonical operating model, in the user's words (2026-06-08). Every minute
labeled with the [primitives](PRIMITIVES.md) it activates; every person's job
clear. This is both the **dream** ([VISION.md](VISION.md)) and the app's
**acceptance contract**: every screen is measured against *"would this survive
in that day, at that footprint?"*

> The room does the teaching. The verbs do the guiding. The teacher does the
> seeing. **The app does the remembering.**

## The footprint that must hold

**Under 12 minutes of screen time in the whole day. All teacher-facing. Zero
kid-facing.** The app touches the day **four times** — everything else is human:

| Touch | Budget | Backed by |
|---|---|---|
| Record mood | 5 sec (10 taps) | `EntryKind.mood` entries |
| Record verb picks | 10 sec/kid | `ActionWordsActions` (action_words_providers.dart) |
| Pick an activity from today's picks | 15 sec | `matchActivities(picks, activities)` (activity_match.dart) |
| Parent messages | 10 min, after kids leave | `buildParentMessage` (parent_message.dart) + `/action-words/send` |

The closing reveal (the day's emotional peak) is a fifth optional teacher touch
— now a one-tap CTA via `revealAllPicksToday` (the day-flow "Closing time" card).

The people: **teacher** sees · **helper** models (writes their own sentence,
draws alongside, supervises safety) · **kids** run the room through their
picked verbs (Movers CARRY, Navigators FLOW, Scouts WATCH, Spark Plugs PLAY,
Buddies HELP, Ears LISTEN, Anchors WAIT, Spotlights SHINE, Makers BUILD,
Translators ECHO).

---

## 6:45 AM — Teacher arrives alone
*Primitives: none yet — setup.*

Open the binder to today's page. Read it once. Set out the 12 verb cards in a
messy scatter on the picking table. Check the art station — crayons, pencils,
paper stocked. Write today's Wall question on a large sticky note — **hold it,
don't post it yet.** Charge the speaker. Open the app, glance at yesterday's
data for 30 seconds — who was what, any patterns. Close the app. Phone in
pocket. Check the Shelf — yesterday's journals, spines out. The room is ready.
You're ready. **15 minutes. No kids yet.**

## 9:00 — Door greeting
*Primitives: Name. No screen.*

You stand at the door. Every kid gets their **name said correctly + one
personal thing + eye contact at their height.** "Hey Leah, love the braids."
"Marcus! How's Bear?" "Sofia — your mom said you lost a tooth, let me see!" The
helper is inside, guiding kids to backpacks, journals from the Shelf, the
circle. **The most important 5 minutes is a human voice saying a child's name
like it matters.** ~10 min as kids trickle in.

## 9:10 — Mood Weather
*Primitives: Circle, Question, Timer, Three. App: 5 sec.*

Everyone in the circle. Hold up the Mood Weather card. "1 is stormy, 5 is sunny.
In 3… 2… 1… show me." All fingers up at once. Scan. Note the 1s and 2s —
**don't call anyone out.** "I see you. Thank you." Helper models. Tap moods into
the app — ten taps, five seconds. **2 min.**

## 9:12 — Verb pick
*Primitives: Verb, Three, Pick. App: 10 sec/kid.*

"Verb cards are on the table. Go pick your three." Kids walk to the table, look
at the 12, pick 3, bring them back. Some pick fast, some stare 30 seconds —
both fine. Helper reads verbs aloud for non-readers. **No guidance on what to
pick. Their pick is their pick.** Record name → three verbs in the app. **3–4
min.**

## 9:16 — Word of the day
*Primitives: Name, Three. No screen.*

"Today's spell is LUMINOUS. Say it. Whisper it. SHOUT it." (laughter) "It means
glowing with soft light. Like a candle. Like the moon. **Use it 3 times today
and it's yours. I'll be listening.**" Tape the card to the board. **1 min.**

## 9:17 — Verb jobs assigned
*Primitives: Verb, Name. No screen.*

"Who picked CARRY? You're our **Movers** — when I need something carried, you
carry it." "Who picked FLOW? You're our **Navigators** — you lead us when we
walk." Just the 4–5 most-picked verbs out loud; the rest get their job
privately (helper whispers: "You picked WATCH. You're the **Scout** — tell me
what you notice at closing"). **2 min.**

## 9:19 — "If I were" prompt
*Primitives: Question, Pick. No screen.*

"If I were a sound, I would be ___. Think. Don't say it yet." (5 sec silence)
Then around the circle. No commentary, no "good answer" — just nod, point to the
next. "Thunder." "A purr." "My mom laughing." "I don't know yet." **All valid**
— "I don't know yet" is a real answering move. Helper saves 2–3 for the Wall.
**3 min.**

## 9:22–9:23 — Transition + writing drill
*Primitives: Timer (30 min), Verb, Book. No screen.*

"Navigators — lead us to the writing tables." (FLOW kids stand first; their pace
sets the room's.) "Movers — pass out pencils and paper." (CARRY kids distribute
— **their verb IS their job, no extra instruction.**) Binder, Day 14: *"Write
'I like ___ because ___.'"* Teacher demos one on the board; kids copy + fill in.
**Helper sits WITH kids and writes their own sentence** ("I like mornings
because the room is quiet") — normalizing writing — then circulates. Movers
collect finished papers into journals. Scout watches. **22 min of writing.**

## 9:45 — Movement break
*Primitives: Timer (3 min), Verb (PLAY). No screen.*

"Spark Plugs — wake us up." (PLAY/SPARK kids decide: jump, dance, spin.) If
nobody picked PLAY, cast the **MOVE** spell. Sharp transition back. **3 min.**

## 9:48 — ABC / phonics
*Primitives: Timer (30 min), Name. No screen.*

Binder, Day 14: speed round — hold up a card, kids shout letter AND sound, fast.
Then missing-letter ("A, B, _, D — what's missing?"). **Feels like a game, not a
lesson.** Helper runs a slower small group. **Ears** report which letters got
confused ("everyone said B for D"). **25 min, multiple mini-games, never one
thing >5 min.**

## 10:15–10:30 — Transition + snack
*Primitives: Verb (CARRY, FLOW), then none. No screen.*

Movers carry the basket, Navigators lead, Buddies seat everyone. Then **eat,
talk, laugh — teacher and helper eat too.** "Did anyone use LUMINOUS yet?"
(count the hands). **15 min of breathing space.**

## 10:30 — Read-aloud
*Primitives: Circle, Name, Question. No screen.*

Close circle. Book facing out, point to every word, voices + drama, pause before
repeated phrases so kids fill them in (**performing reading**). After: "What did
you notice?" — two answers only. **Translator** retells it in their own words
(comprehension without a worksheet). **20 min.**

## 10:50 — Drawing / shapes
*Primitives: Book, Timer, Name. No screen.*

Binder, Day 14: observational drawing — *"Draw EXACTLY what you see, not what you
think a plant looks like."* "LUMINOUS work on that stem." Helper draws alongside.
Makers organize supplies; Spotlights share with a neighbor. **Drawings go in the
journal — evidence, inventory growing.** **25 min.**

## 11:15 — Lunch + free play
*Primitives: Verb, Timer. No screen.*

Lunch 20 min. Free play 25 min — **kid-led.** Spark Plugs start games,
Navigators go to the kid sitting alone, Scouts watch. **The verbs run the room
without the teacher doing anything.** Helper counts heads every 5 min.

## 12:00 — Quiet book time
*Primitives: Book, Timer (20 min), Verb (WAIT, LISTEN). App: teacher prep.*

Each kid picks a book, "reads." **Anchors** model calm (still, slow page turns)
— their energy calms the room. Teacher uses this to check the app, write quick
notes, photograph the Wall, prep Verb Hour. **Guard this time — it's the room
breathing.** **20 min.**

## 12:20 — Post the Wall question
*Primitives: Wall. No screen.*

Walk to the Wall. Stick today's question at the top: *"What's something you can
feel but can't see?"* Sticky notes + pens nearby. **Open for business all
afternoon.** **1 min.**

## 12:21 — VERB HOUR (the heart)
*Primitives: Verb, Three, Timer, Question, Name, Reveal, Wall. App: 15 sec.*

Open the app 15 seconds: **today's picks → which activities match → pick one**
(`matchActivities`). Most picked CARRY/LISTEN/BUILD → the app suggests **Blind
Building** (one partner describes a structure unseen, the other builds from
words alone — LISTEN + BUILD + CARRY).

- **Min 0–5 — PLAY it.** "Pair up. Builder: 5 blocks behind a barrier, describe
  with words only. Partner: build what you hear. GO." Chaos, laughter,
  frustration, joy. **This IS the learning.**
- **Min 6 — NAME it.** Ring the bell. "What you did has a name. **COMMUNICATION.**
  Whisper it. That's turning a picture in your head into words, sending them
  through the air, and someone turning them BACK into a picture. You moved an
  idea from one brain to another using nothing but sound."
- **Min 8 — BRIDGE it.** "Where else? Radio — they describe, you imagine. Deeper:
  your mom at work is thinking about you right now; tonight your words build your
  day in her head. Deepest: someone wrote on a clay tablet 3,000 years ago and
  you can read it — their brain sent a message across 3,000 YEARS into yours."
- **Min 11 — QUESTION it.** Walk to the Wall. Write: *"What can't you communicate?
  What's something you can't turn into words?"* Stick it. **Say nothing. Walk
  away. Let it hang.**
- **Min 12–50 — more activities.** 2–3 more, same formula (play → name → bridge
  → question) — or skip the philosophy and just DO. **Read the room:** energized
  → keep playing; reflective → go deep. Kids add to the Wall whenever; helper
  writes for non-writers.
- **Min 50–55 — wind down.** Cast **WONDER**. Two minutes of silence. DOING →
  REFLECTING.
- **Min 55–60 — mission check.** Walk around, check each kid's three verbs against
  what they did. "Leah — CARRY, LISTEN, BUILD?" "I carried the blocks / listened
  to Sofia / built her tower from words." "All three. Done." Mark in the app —
  three taps/kid, 60 sec for all ten.

**60 minutes. The biggest block. The heart of the day.**

## 1:21 — Movement break
*Primitives: Timer. No screen.* Outside if possible. Run, climb, yell. **15 min.**

## 1:36 — Book + draw time
*Primitives: Book, Timer, Name. No screen.*

"Draw what you built during Verb Hour. One page. Make it good." **Today's
experience becomes a permanent page.** Helper helps label/spell. Spotlights
share. **25 min.**

## 2:01–2:03 — Closing: verb-guessing game
*Primitives: Circle, Verb, Reveal, Name, Timer. App: optional reveal.*

Navigators lead to a tight circle, knees close, energy shifts quieter. A
Spotlight goes first — steps to the center, **acts out one verb, no words.** The
circle shouts "CARRY!" then "ANT! ELEPHANT! BEAR!" Teacher holds the world card
face down. "Leah — you carried, you listened, you built. You know who does all
three?" *Flip.* "🐝 **A BEE.**" The room erupts. **Her collection grid gets a new
color-in tonight.** 3–4 kids get the full theatrical reveal; the rest a quick
one ("Marcus — Eagle. Sofia — Water"). For the shy kid: "Class — what do you
think Ava was?" "Owl! She was quiet and watched everything!" **Seen without
performing.** **10 min.**

## 2:13–2:21 — Wall review · spell check · best part · Shelf
*Primitives: Wall, Question, Circle, Name, Three, Book.*

- **Wall review.** "What do you notice?" "Lots of people said 'love.'" "I said
  'my dog's feelings' because I can feel when he's sad but I can't SEE it." *"Say
  it again."* Then **let it hang — that answer is worth more than anything you
  could teach.**
- **Spell check.** "LUMINOUS — who used it? How many times?" Three uses from three
  kids → it's earned, onto the Word Wall **forever.**
- **Best part.** "Three people — best part of today?" "Using LUMINOUS at recess
  and Jayden looked at me like I was smart." **Write that one down — tell the
  parent tonight.** (Fridays: each kid's whole week in one sentence → journals.)
- **Books on Shelf.** "Today's page in your journal. Journals on the Shelf, spine
  out." "Look at that Shelf — you made all of that. Every page." Pause. "See you
  tomorrow."

## 2:23 — Departure
*Primitives: Name. No screen.*

Arrival reversed. Each kid: **name + one specific thing from today + eye contact.**
"Leah — that 'dog's feelings' answer? I'm still thinking about it." "Ava — the
class saw you. Best Owl I've ever seen." They leave. The room is quiet. ~10 min.

## 2:35 — Teacher alone: parent messages
*Primitives: Name, Verb, Reveal, Question. App: 10 min.*

Tap each kid — the message auto-generates (`buildParentMessage`). Read it, **add
your one personal sentence**, copy, send.

> Leah was 🐝 Bee today. She practiced CARRY, LISTEN, BUILD. She built a tower
> from only verbal instructions — communication in action. Today's word:
> LUMINOUS ✓. She also gave the best Wall answer I've ever heard: *"I can feel
> when my dog is sad but I can't see it."*
> 💬 Ask at dinner: "What would a bee build if it could build anything?"

Ten messages, ten minutes. Photograph the Wall, archive the sticky notes. Check
tomorrow's binder page. Put the verb cards back in the basket. **Look at the
room — full of evidence, full of today.** Close the door.

---

## The whole day in primitives

| Time | Event | Primitives | Screen? |
|---|---|---|---|
| 6:45 | Setup | — | 30-sec glance |
| 9:00 | Door greeting | Name | No |
| 9:10 | Mood Weather | Circle, Question, Timer, Three | 5-sec record |
| 9:12 | Verb Pick | Verb, Three, Pick | 10-sec/kid record |
| 9:16 | Word of Day | Name, Three | No |
| 9:17 | Verb Jobs | Verb, Name | No |
| 9:19 | If I Were | Question, Pick | No |
| 9:23 | Writing | Timer, Book | No |
| 9:45 | Move | Timer, Verb | No |
| 9:48 | ABC | Timer, Name | No |
| 10:17 | Snack | — | No |
| 10:30 | Read-Aloud | Circle, Name, Question | No |
| 10:50 | Drawing | Book, Timer, Name | No |
| 11:15 | Lunch + Play | Verb, Timer | No |
| 12:00 | Quiet Books | Book, Timer | Teacher prep |
| 12:21 | **Verb Hour** | Verb, Three, Timer, Question, Name, Reveal, Wall | 15-sec pick |
| 1:21 | Move | Timer | No |
| 1:36 | Book + Draw | Book, Timer, Name | No |
| 2:03 | Closing Game | Circle, Verb, Reveal, Name, Timer | Optional reveal |
| 2:13 | Wall Review | Wall, Question, Circle | No |
| 2:16 | Spell Check | Name, Three | No |
| 2:18 | Best Part | Circle, Question, Name | No |
| 2:21 | Books on Shelf | Book, Name | No |
| 2:23 | Departure | Name | No |
| 2:35 | Parent Messages | Name, Verb, Reveal, Question | 10 min |

**Total screen time: under 12 minutes. All teacher-facing. Zero kid-facing.**

Same rhythm tomorrow. Different verbs. Different world. Same room getting
fuller. Same ten primitives turning in ten different combinations. *That's
Different World. One day at a time.*
