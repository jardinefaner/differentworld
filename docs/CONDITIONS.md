# Conditions, not content — and the three acts

> A tool that creates **conditions**, not one that creates **content**.

This is the scalability doctrine. [VISION.md](VISION.md) says what the app
is for and [AI_BOUNDARY.md](AI_BOUNDARY.md) says where machines may stand;
this says how the thing grows without somebody hand-writing every riddle
until they die.

---

## The measurement that settles it

Two ways to add to this app, both already tried here:

| | shipped | bought |
|---|---|---|
| **Content** | 16 curated seeds · 40 picture cards · 14 Wordle words · 9 scavenger prompts · 3 crosswords | Exactly itself. Forty cards is forty cards; the forty-first needs a person. |
| **Conditions** | **1** grid shape | **19 classics**, ~20 lines each — and every one plays with whatever a room brings to it. |

Content scales **linearly** with author-hours. Conditions scale
**multiplicatively**: one shape times every game that fits it, times every
room's own material.

We found this by accident. The shape protocol was built to stop a game
costing 500 lines, and the interesting result was not the saved lines —
it was that a *grid* turned out to be a condition, and nineteen games
were already inside it.

**The doctrine: prefer the thing a room fills to the thing we filled.**

---

## The three acts

Borrowed from film, because the shape fits and because it makes the AI
rule obvious rather than a thing to memorise.

### Act one — set the condition (pre-production)

The schedule, day templates, activity decks, the content bank, the
picture library. Everything decided **before** anybody is in the room.

**AI is allowed here.** It drafts; a person edits; nothing reaches a room
unreviewed. A teacher facing a blank "make a scavenger list" is a teacher
who does not make one, and a drafted list they cross half out of is a
better list than either would have written alone.

### Act two — the room fills it (production)

The cockpit, the cast, the nineteen games, capture, attendance. The live
hour.

**No AI. None.** This is the stage, and the stage is people, objects,
movement and conversation ([AI_BOUNDARY.md](AI_BOUNDARY.md)). Whatever
happens here is the children's, and a machine that joins in has taken
their turn.

Note what act two *is*: the condition is empty until a room arrives. This
or That has no opinion about pizza or tacos — it is two things and the
word *or*. The room supplies the things.

### Act three — keep what happened (post-production)

The book, the recap, exports, the growth arc.

**AI is allowed here**, on the same terms as act one: it assembles
material that already exists, and an adult approves before a family sees
it. It never narrates — a generated voice telling a family who their
child is becoming is the machine speaking about a person.

**The rule falls out of the acts rather than needing to be remembered:
machines work before and after the show, never during it.** That is the
same sentence as backstage/frontstage, said in a different room.

---

## What this changes about content

Most bundled content is a condition wearing content's clothes. The test:
**could the room supply this better than we can?** If yes, ship the shape
and an empty seat.

| Today | As a condition |
|---|---|
| 40 This-or-That pairs | Two things and the word *or* — the room names both |
| A bundled Guess Who deck | The children's own faces, which are already in the app |
| 9 scavenger prompts | What is actually outside *this* door, listed by the teacher who can see it |
| 40 picture cards for Bingo and Memory | This week's photographs |
| 14 Wordle words | The words this class is learning |

None of these are worse for being empty. Several are the *point*: a Guess
Who of the children in the room is a different game from a Guess Who of
stock cartoons, and it is the better one.

**Bundled content does not go away.** It is the seed that makes day one
work, and the fallback when nobody has authored anything yet. It stops
being the plan.

---

## How a user helps create it

The elegant version is that **authoring is not a place you go.** A
separate "content management" area is a second job handed to somebody who
already has one, and it will be empty in every program that most needs
it.

Three routes, in the order they cost a teacher anything:

1. **Authoring by playing.** A teacher who runs Scavenger Hunt with their
   own list has authored content and never visited a settings screen. The
   activity's own surface offers "use our own" and keeps what was typed.
   This is the one that actually scales, because the cost is zero above
   playing the game.
2. **Authoring by keeping.** The room made something good — a round, a
   list, a set of pairs. One button turns this-time into every-time.
   Nothing is authored speculatively; things become durable *because they
   worked*.
3. **Authoring deliberately.** The libraries that already exist —
   activities, the picture library, day templates, routine scripts. Right
   for a director on a planning afternoon, wrong as the only door.

### What is built (2026-09-07)

Routes 1 and 3 both exist now, and they are the SAME door reached from two
places — a single kind schema
(`lib/features/game_content/content_kinds.dart`) that fifteen content kinds
declare themselves in, and one generated form, list and index built from it.
Adding a sixteenth kind means adding a `ContentKindSpec` and nothing else;
a test fails if a `ContentKind` ships without one.

- **Route 3** — `/library/ours` lists every kind with how many this program
  has written; `/library/ours/:kind` is add / edit / remove-with-undo.
- **Route 1** — `OursStrip` sits on the game's end-of-round beat
  (`game_scaffold.dart`, so all 41 games at once) and reads
  "40 ready · 2 pairs yours · Add ours", plus `OursFooter` on the four
  activities that are their own screen rather than a game. It is suppressed
  in kid mode and on any cast / speak stage — the door leads OUT of the
  activity — and it is on the WRAP beat rather than mid-play deliberately: a
  teacher authors between rounds, never while thirty children wait.
- **Route 2** — authoring by keeping. This doc previously claimed it
  "already existed as `CaptureSpec`'s crowd-grow". **That was wrong**:
  `CaptureSpec` was declared, never overridden by any game, and read by
  nothing, so no round ever banked anything. It has been deleted. What
  exists now is `GameDefinition.keepsake` + `KeepThisButton`, which write
  an `EntryKind.classMemory` — and deliberately for only a FEW activities
  (Scattergories, Penny, Potions), because a memory full of "Team 1 wins"
  buries the things worth keeping.

Authored rows carry `space_id` + `source='staff'` and fingerprint on their
own id, so two identical items both survive — a room is allowed to repeat
itself. They merge into `bankedContentProvider` alongside the curated seeds
with **zero game-side code**: an activity cannot tell the difference between
a line we shipped and a line the room wrote, which is the whole point.

What remains: `picture` keeps its own camera-shaped library (its payload is
an upload, not typed fields), and the strip is mapped to 13 activities —
kinds with no activity route yet (`quote`) are reachable only through the
library.

---

## The rule for new work

Before adding content, ask: **is this a thing only we can supply, or a
thing a room would supply better?**

- Only we can supply it → bundle it, and it is content.
- A room supplies it better → build the seat, seed it thinly, and let the
  room fill it. That is a condition, and it will outlive the seeding.

And before adding an authoring surface, ask **which act it belongs to**.
Act one, before the room, with a person reviewing. Never act two: a
teacher should not be authoring while thirty children wait.
