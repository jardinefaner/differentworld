# ASSETS — everything that brings the system to life

The full Different World asset manifest, in the user's words (2026-06-08). The
operating intent: **already laid out before printing — the teacher does
nothing; every printable is pre-formatted to how it gets printed.**

> The assets disappear. The teacher appears. The kid is seen. *That's the
> product.*

This doc is the canonical asset spec AND the build map. The code-actionable
slice is the **8 print bundles** + the digital exports (poster, report); the
rest (cards stock, journal binding, bracelets, pins, room kits, audio, video,
the box) are manufacturing / AV, captured here as the product vision.

---

## Print-readiness audit (the 8 bundles vs. the `/print` toolkit)

`lib/features/toolkit/toolkit_pdf.dart` generates offline Helvetica PDFs today.
Status: ✅ done · 🟡 partial · ⛔ missing (needs content and/or a generator).

| Bundle | Contains | Status |
|---|---|---|
| **1 · Daily Essentials** | verb cards ✅, timer-spell cards ✅, mood card ✅ (reference), repair script ✅ (reference), schedule ⛔ | 🟡 |
| **2 · Journal Inserts** | avatar strips, mood logs, ally page, collection grid, verb circles, spell-book pages, journey checklist, quest tracker | ⛔ |
| **3 · Wall + Prompts** | 50 Wall question cards, 50 If-I-Were prompt cards (color-coded by depth) | ⛔ *(no content bank)* |
| **4 · World Activity Sheets** | world summary posters ✅; 6–8 activity sheets × 10 worlds ⛔ | 🟡 |
| **5 · Teacher Reference** | verb→job ✅, repair+mood ✅, gesture guide ✅; daily-pick sheet, skill tracker, beautiful-words list, play→name→bridge→question card, activity-formula card ⛔ | 🟡 |
| **6 · Parent Pack** | welcome letter, daily template, gallery invite, weekly summary | ⛔ |
| **7 · Closing + Reveal** | gesture guide ✅, world reveal cards ✅; closing-game variations ⛔ | 🟡 |
| **8 · Showcase** | certificate, gallery labels, room-comparison frame, summer-report template (summer_book.dart exists) | ⛔ |
| **Spell Word cards** | 30 "precious" word cards (gold front; definition + gesture + "use 3×" back) | ⛔ *(no content bank)* |

**The two blockers are CONTENT, not layout:** the spell-words (30), wall
questions (50), and if-i-were prompts (50) catalogs don't exist in the app yet.
Authoring those also content-completes the DAILY system (THE_DAY.md's "Today's
spell is LUMINOUS," "Today's Wall question," "If I were a sound"), so they're
high leverage — they power the app AND three print decks.

---

## PHYSICAL CARDS + GAME PIECES
- **12 Verb Cards** — heavy cardstock, rounded corners, emoji front, verb +
  one-line description back. Kid-hand-sized, laminated. Touched 50×/day; must
  survive. *(print ✅)*
- **World Reveal Cards** — 40, one per world. Giant emoji front; world name +
  three verbs + essence back. Thicker stock — the teacher holds them up; the
  flip is the moment; the card needs weight. *(print ✅)*
- **Spell Word Cards** — 30. Word in gold foil front; definition + gesture +
  "use 3 times to earn" back. Each feels precious because the words ARE.
  *(print ⛔ — needs the words)*
- **Wall Question Cards** — 50 in a box, color-coded edges by depth (green =
  concrete · yellow = sensory · orange = emotional · red = philosophical ·
  purple = personal). One pulled daily. *(print ⛔ — needs the questions)*
- **If-I-Were Prompt Cards** — 50, same depth color system, separate box.
  *(print ⛔ — needs the prompts)*
- **Timer Spell Cards** — 5 poster-sized (FREEZE · CREATE · SHARE · MOVE ·
  WONDER); emoji fills the card, visible across the room. *(print ✅)*

## THE JOURNAL
Not a composition notebook — custom. Cover: kid writes their name + draws their
avatar in a frame; small program logo. Inside front: a clear pocket for the
**Declaration card** (swapped when the title changes; old cards stay stacked
behind). First section: a pre-printed **avatar-evolution strip** across the top
of 5 pages (one per world theme). Middle: **lined-left / blank-right** spreads —
write on the left, draw on the right. Back: pre-printed templates (mood-weather
log ×10 weeks, ally page, collection grid, verb-frequency circles, spell-book
slots ×30, journey checkboxes 1–50, quest tracker). Back inside cover: a
**mirror sticker** — open the back and you see yourself. *The last page of every
book is you.*

## PHYSICAL ENVIRONMENT
- **The Wall Kit** — 20 large header cards (OUR WORDS / OUR ANSWERS / OUR
  QUESTIONS / WORLD OF ME / …), 500 sticky notes in program colors, removable
  mounting tape, setup instructions.
- **The Shelf Label** — a carved/printed "OUR BOOKS" sign in the program font.
- **Journey Line** — a 6-ft printed banner, 1–50, velcro dots for avatar cards
  + 15 blank avatar blanks.
- **Room Transformation Kits** — one per world: *Me* (mirrors, body-outline
  roll, fingerprint ink) · *Nature* (magnifiers, seed cups, bark crayons, bug
  viewers) · *Water* (cups, funnels, eyedroppers, food coloring, sponges) ·
  *Music* (rhythm sticks, shakers, rain stick, drums) · *Space* (glow stars,
  flashlights, black paper, white crayons) · *Dreams* (sleep masks, dream
  inserts) · *Time* (sand timers 1/3/5, magnifier, "old things" cards) ·
  *Feelings* (color-mix cups, a balloon, mirror cards) · *Stories* (object bag,
  shadow-puppet sticks) · *Us* (string for the web, certificate blanks, gallery
  mounts).

## WEARABLE / TACTILE
- **Verb Bracelets** — silicone, 12 colors, emoji debossed. Wear your 3 picks;
  "What are your verbs today?" → hold up the wrist. No screen.
- **World Pins / Badges** — enamel pins / iron-on patches, one per world.
  Earn the world → get the pin. The collection is wearable, visible, earned.
- **Name Tag System** — reusable, clear window. Name stays; a slot below holds
  today's world emoji card. "Leah — 🐝." Changes daily.

## AUDIO
- **Morning Chime** — one fixed sound at 9:00, never changes. By Day 5 the sound
  means "it's starting."
- **Spell Sounds** — FREEZE = crystalline chime · MOVE = drumbeat · CREATE =
  rising tone · SHARE = warm bell · WONDER = silence (the sound IS its absence).
- **World Reveal Sound** — one sound, only at the closing reveal. A gong / a
  sparkle / a building hum. By Week 3 the sound alone makes them lean forward.
- **Background Ambience per World** — quiet playlist per theme (forest, ocean,
  space drones, soft piano; Music = silence). The room *sounds* like the world.
- **A Different World Anthem** — four hummed notes the kids learn; their anthem
  from Week 5, recorded by them. *Made by them, not for them.*

## DIGITAL ASSETS
- **The App** — teacher-facing (picks, matcher, timers, parent messages,
  collection); kid-facing optional (picker, three dots, reveal, grid). *(built)*
- **Reveal Animations** — one per world, ~5s: black → three verb emojis appear →
  pause → world emoji scales up with a glow → name fades in. 40 total. Dark,
  minimal, no cartoon sounds.
- **Parent Daily Card** — auto-generated shareable image (world emoji, name, 3
  verbs, word, dinner question). The image IS the message. *(text ✅ via
  buildParentMessage; image render ⛔)*
- **Weekly Summary Card** — same, weekly.
- **Summer Report** — final auto-PDF per kid: title evolution, worlds, verb
  frequency, words, skill graphs, best Wall answers, teacher notes, photos.
  *The report IS the proof.* *(summer_book.dart is the seed)*
- **Collection Poster** — printable 11×17 of the kid's grid (worlds colored,
  verb bars, title). Printed at a pharmacy, framed, on the bedroom wall.
  *(poster_engine.dart is the seed)*

## VIDEO ASSETS
- **World Introduction Videos** — one per theme, 60–90s, atmospheric (forest
  dawn, a water drop, the Pale Blue Dot zoom, morphing clouds, one held note).
- **YouTube Playlist per World** — 3–5 pre-screened, unlisted. Tap, play, done.
- **Showcase Video** — teacher-assembled slideshow of 10 weeks (empty room →
  Day 1 faces → the Wall growing → the Shelf filling), set to the kids' anthem.
  *Parents cry. The video IS the narrative.*

## THE PRODUCT (the box)
One **Different World Box** = everything a class of 15 needs for 10 weeks: the
laminated card sets, 30 spell-word cards, the two prompt-card boxes, 15 custom
journals, the Journey Line, the Wall Kit, the Shelf Label, 15 bracelet sets, a
USB (all 8 PDF bundles + 10 intro videos + 10 playlists + reveal animations +
ambient audio + the app link), the pre-tabbed Teacher Guide binder, and a Quick
Start card: *"Open the binder to Day 1. Read it. Do it. That's the whole job."*
**$200–400 / box** (~$1.50–3.00 per kid per week). **Refill kit $50** (journals,
sticky notes, replacement cards).

---

## The one thing no box contains
The teacher at the door at 9:00 saying a kid's name like it's the most important
word in the world. Every asset exists to make that moment possible — and if they
do their job, *the teacher forgets they exist.* The binder is open but unread.
The app recorded the picks but goes unwatched. The Wall fills without being
managed. The assets disappear; the teacher appears; the kid is seen.
