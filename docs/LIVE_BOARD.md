# The Live Board — the phone as a classroom instrument

The present layer isn't only pre-built slides and games — it's a **live canvas
the teacher plays from the phone**, moment to moment, for the unscripted parts
of class. Tap a word while reading and it highlights big on the room screen; a
kid asks how to spell something and you tap their name + type it and the room
sees the avatar and the word, big. (Vision: "the phone as the live classroom
instrument", 2026-06-13.)

## The one idea

The board is a **rack of small instruments**. Each instrument is a tiny control
on the phone that pushes ONE auto-fit big layout to every screen in the room.
Same shape every time: *phone control → broadcast → big render*. New instruments
are cheap; the spine is shared.

**Design law (enforced on every instrument): auto-fit.** The room render always
scales its content to fill the screen and never scrolls, never clips
(`FittedBox`). "All must fit in screen" is the rule, not a nice-to-have.

## How it rides what already exists (no new realtime code)

The board is a **cast-only `GameDefinition`** (`BoardGame`, like `WorldCastGame`
/ `ConductorGame`), registered in `game_registry.dart`. That means:

- **The existing Cast receiver renders it for free.** `cast_receiver.dart`
  already does `gameById(meta.game).buildStage(...)` — register `BoardGame` and
  any screen that joins the cast code shows the board. Zero receiver changes.
- **One phone → many screens is already true.** The cast spine broadcasts
  canonical state to every device on the join code (`live_session.dart`), and
  re-broadcasts on each join. The board inherits it.
- **The caster drives via `castStage('board', state)`** — the same explicit-
  state push the world slideshow uses. Every edit re-casts the full board
  wire-state; the reducer is a no-op (no per-keystroke intents to design).

So the only NEW code is: (1) `BoardGame.buildStage` — the auto-fit renders; and
(2) `LiveBoardScreen` — the phone caster (the instrument rack + a live preview +
the join code).

## Wire-state

`{ 'kind': 'idle' | 'word' | 'spell', 'word': String, 'name': String }`
Self-describing (the framework's content-free-reducer rule): the receiver draws
it with no roster/catalog access — the caster puts the kid's name in the state.

## Instruments

**Shipped (Wave 1)**
- **Big word** — type a word; the room shows it huge, auto-fit.
- **Spell-for-me** — pick a kid (roster avatar) or type a name + a word; the
  room shows the avatar (initials) and the word, side by side, big.

**Next (Wave 2+ — the "what else")**
- Highlight-a-word reading (paste text up big; tap a word → it bolds) — reuses
  the `speak/` engine's active-word highlight + the 15 auto-fit layouts.
- Reveal a word/sentence one piece at a time · sound-it-out (syllables) · big
  number + live tally · whose-turn (push an avatar) · show-and-tell (push a
  drawing) · spotlight/point · attention-cue · hold/freeze.
- Per-screen *independent* control (stations/centers) — needs per-target
  addressing on top of the broadcast; the rest are mirror-all.

## How a teacher uses it

1. Open **Live Board** (Present hub / omnibox). It shows a join **code**.
2. Each room screen joins via **Cast → Be the screen → enter the code** (the
   existing receiver). "N screens connected" confirms.
3. Pick an instrument, drive it; every screen updates live. A preview on the
   phone shows exactly what the room sees.

## Lifecycle / correctness notes

- `LiveBoardScreen` owns one `CastSession.cast(code)`; create in `initState`,
  `dispose()` it in `dispose`. All `states`/`peers` listeners guard on
  `mounted` (the Realtime callbacks can fire after dispose — see the Wave 0c
  add-after-close gotcha; `CastSession`/`LiveSession` already guard their sinks).
- The board is **ephemeral coordination, not data** — nothing persists, same as
  every cast (it does NOT go through PowerSync).
