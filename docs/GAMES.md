# The Games Deck — 20 brain breaks, built for present + control

The catalog for [VISION.md](VISION.md) #4 (no-typing, host-present games)
and #14 (Live Sessions). Every game here is designed against one principle.

> "think of how the phone as remote and web/desktop as presentation view"

## The principle: every game is two (sometimes three) views

- **Presentation** — what the *room* sees. The big screen: a projector, a
  TV, a desktop/web window. Big text, color, the dramatic reveal.
- **Control** — what the *teacher* drives. The phone in their hand: a
  remote. Next / Back / Reveal / pick a topic / keep the tally / start a
  timer. The room never watches the controls.
- **Secret** (some games) — what *one player* sees privately on their own
  phone, hidden from the room. The thing that makes Charades work.

Today every game runs **single-device** (This-or-That already splits
Presentation vs Control on one screen — see `this_or_that_screen.dart`).
The **two-device** version — phone controls a separate projected screen —
is the [LIVE_SESSIONS.md](LIVE_SESSIONS.md) layer: lift each game's state
behind a `SessionController`, and the same Presentation/Control widgets
render on a desktop and a phone joined to one session. **Build that seam
once and all 20 games get present-on-the-big-screen / control-from-the-phone
for free.**

`✓` = built today · `+` = designed, not built.

---

## Think — puzzles & logic
- **✓ Riddle Me This** — a riddle to solve aloud.
  *Big:* the riddle. *Phone:* Reveal the answer · Next.
- **✓ Fact or Fib** — true, or made up?
  *Big:* the statement (room votes with hands / move to a side). *Phone:*
  Reveal "True!" / "Fib — here's the real fact" · Next.
- **+ Odd One Out** — which doesn't belong, and why?
  *Big:* four things. *Phone:* Reveal the odd one + the reason · Next.
- **+ Brain Teaser** — the puzzle of the day.
  *Big:* the teaser. *Phone:* Hint · Reveal · Next.
- **+ Emoji Decode** — guess the phrase from the emojis. 🍿🎬 = movie night.
  *Big:* the emoji string. *Phone:* Hint · Reveal · Next.

## Numbers
- **✓ Math Game** — one question at a time.
  *Big:* the problem + options. *Phone:* Reveal (the answer glows) · Next.
- **✓ Many Paths** — how many ways to a number?
  *Big:* the target + the room's paths. *Phone:* capture a path · Next.
- **+ Estimate It** — how many jellybeans? how tall? how long is a minute?
  *Big:* the thing to estimate. *Phone:* Reveal the real number · Next.
  *(Two-device unlock: the dramatic count-up reveal on the big screen.)*

## Words & language
- **✓ Beat the Letter** — name things that start with the letter.
  *Big:* the giant letter + category. *Phone:* tally ("someone said it") ·
  New letter. *(Two-device: the count climbs live on the big screen.)*
- **✓ Rhyme Time** — how many rhymes can the room find?
  *Big:* the word + the live count. *Phone:* tally · New word.
- **+ Categories** — name as many as you can before time's up.
  *Big:* the category + a big countdown. *Phone:* start the timer · tally ·
  Next. *(Two-device: the countdown belongs on the room's screen.)*
- **✓ Story Starters** — build a story aloud, one line each.
  *Big:* the opener (and a surprise "Twist!" card). *Phone:* Next starter ·
  Add a twist.

## Choose & discuss
- **✓ This or That** — pizza, or tacos?
  *Big:* two colored halves + OR. *Phone:* Reveal "why?" · Back · Next.
- **+ Would You Rather** — the impossible choice.
  *Big:* the dilemma + a live split bar (how the room landed). *Phone:*
  log the split · Reveal · Next.
- **✓ Group Talk** — discuss, by topic & age.
  *Big:* the prompt. *Phone:* pick topic + age · Go deeper · Next.

## Perform & imagine
- **✓ Act It Out** — say the line "as if…".
  *Big:* the line + the emotion. *Phone:* Next · shuffle.
- **✓ Charades** — act it out, no words.
  *Big (room):* the category + the score. *Secret (actor's phone):* the
  word to act. *Phone (teacher):* Got it / Skip. **The clearest two-device
  unlock — the secret word can't be on the screen everyone sees.** Built on
  the generic `LiveSession` seam (3 roles: present / secret / control).
- **✓ Role Cards** — be an animal / person / job for the day.
  *Big:* the chosen card. *Phone:* browse · pick · "Today I am…".

## Move & calm
- **+ Move It** — a movement deck: animal walks, freeze, stretches.
  *Big:* the move, animated, with a timer. *Phone:* Next · shuffle · start.
- **✓ Mindful Minute** — breathe together.
  *Big:* the breathing circle for the whole room to follow. *Phone:*
  start / pause · set how many breaths.

---

## What the two-device model unlocks (beyond a remote)

It's not just "control an existing game from your phone." It enables game
*shapes* a single screen can't do:

1. **Secrets** — Charades: the word on the actor's phone, the timer on the
   wall. Also "Guess Who I Am", "Whisper Down the Lane".
2. **Live tallies & vote splits** — Beat the Letter / Rhyme Time counts and
   Would You Rather bars climb on the big screen while the phone clicks.
3. **Room timers** — Categories / Move It: a big countdown the room watches,
   started and stopped from the phone.
4. **Dramatic reveals** — Estimate It / Riddles / Fact or Fib: the phone
   holds the answer until the teacher chooses the moment; the room only ever
   sees the reveal.

## How it's built (the cheap path)

Per [LIVE_SESSIONS.md](LIVE_SESSIONS.md):

1. **`SessionController` seam (local).** Lift each game's
   `index / revealed / tally / phase` behind an interface. Presentation +
   Control widgets read state / send intents. Single device today — no
   behaviour change. *This-or-That is already shaped this way; the rest
   follow.*
2. **Realtime transport.** A desktop/web **presents** (joins a session,
   renders Presentation); a phone **controls** (sends intents). Join by a
   short code or QR.
3. **Secret view.** A third role for Charades-style games: a phone that
   holds the hidden word.

Build the seam once → every game on this page gains present-on-the-big-
screen / control-from-the-phone. New games are authored as a
(Presentation, Control) pair from the start.

## Build order (suggested)

- **Now (single-device, unblocked):** the 9 `+` games, same host-present
  pattern as the 11 built ones. Quick wins, no new infra.
- **Then (the multiplier):** the `SessionController` seam + Realtime
  present/control — turns the whole deck two-device at once. Best validated
  with the Pixel + a desktop/web window open together.
- **Showcase game for the demo:** **Charades** — it's the one that makes
  "why two devices?" obvious in three seconds.
