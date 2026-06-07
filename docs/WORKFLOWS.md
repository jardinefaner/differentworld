# Afterschool day — workflows × how the app surfaces them

The operational map: an afterschool program's day‑to‑day (ages 4–12, the
primary product context), each workflow paired with **how the app surfaces it
today** and **the opportunity**. This is the "meet the day where it happens"
reference; [VISION.md](VISION.md) is the *why*, [FEATURES.md](FEATURES.md) is
the folder‑grained *what*.

## The through‑line: Today should follow the clock

The afterschool day has a sharp rhythm — a quiet open, an **arrival rush**,
program blocks, a long staggered **pickup**, a closeout. The single biggest
lever is making **Today time‑aware**: the same launchpad should *lead* with
check‑in at 3:00, the live block at 4:00, and pickup at 5:15. Today is mostly
static right now (per‑group cards, Director's Pulse, unread messages); the
phases below all improve once Today tracks the day's phase.

## The day, phase by phase

| Phase (default window) | Staff workflows | Surfaced today | Opportunity |
|---|---|---|---|
| **Open / prep** (~2:00–2:45) | Who's coming · my blocks · prep supplies · scan flags | Schedule, Now/Next, Supplies, Director's Pulse | A **day‑open brief** card (lift the per‑block brief sheet to a day brief) |
| **Arrival rush** (~2:45–3:45) | Check kids in as they trickle in · who's *not here* · arrival notes · snack | Attendance (per‑group + "Take attendance" on Today), morning checklist | Planned **face‑aligned auto‑snap check‑in** + a live **"12 of 18 in · still out: …"** strip; rosters carry *expected‑arrival* |
| **Program blocks** (~3:45–4:45) | Run the block · now→next · rotations · a game/brain break · present to the room · snack | Schedule blocks + Now/Next strip, live‑block capture context, Present/Cast, Brain Breaks/Games, Toolkit, Missions, Role Cards | A **"run this block"** surface bundling activity + supplies + cast + capture |
| **Documentation** (throughout) | Capture a moment (photo/note) · log an incident · "noticed X" | Observations (feed + form + voice), Captures inbox, omnibox capture, Photos | **Structured incident logging** (bump/conflict), exportable — distinct from free‑text observations |
| **Pickup rush** (~4:45–6:00) | Verify authorized pickup · check each kid out · late‑pickup tracking · a quick "today X did…" · trip returns | Pickup (authorized + windows), Vehicles (check‑in/out, QR, headcount), Messages | A **time‑aware Pickup board on Today** — who's still here, authorized, late‑pickup timers, one‑tap "release to {guardian}"; deferred late‑pickup push |
| **Closeout** (end of day) | Headcount = 0 · clean up · follow‑ups · notes for tomorrow | Vehicles headcount, Tasks | A **"Close the day"** checklist + a satisfying zero‑state |
| **Family comms** (async) | Message a parent · share a photo/update · send a report | Messages, Family lens, Exports | Planned **"photo of the moment" on Family Today** (Lauren's Spanish localization is the unlock) |
| **Director / behind the scenes** (periodic) | Roster · staff scheduling + **substitutes** · curriculum · reports · surveys · compliance | Subjects/Groups, Schedule + weekly template, Curricula, Exports, Surveys, Insights, Certifications, Director's Pulse | Planned **substitute handoff** + open/close **day bookends** |

## The three highest‑leverage gaps (the build roadmap)

1. **Time‑aware Today** *(cheapest, highest impact — build first)* — a `DayPhase`
   derived from the clock (afterschool defaults, later program‑configurable) +
   a leading **"Right now"** card that switches by phase: arrival → check‑in,
   program → the live block, pickup → pickup. It *reorders/leads* what's
   already there; no new data layer for v1.
2. **A real Pickup board** — mirror the arrival rush's importance: a dismissal
   board (still‑here · authorized · late timers · one‑tap release). Pairs with
   the deferred late‑pickup push.
3. **Structured incident logging** — a first‑class, exportable incident capture
   (kind, who, what, follow‑up) separate from observations — a real afterschool
   compliance need.

## Status

- **Map:** this doc.
- **Build:** wave 1 = time‑aware Today (`DayPhase` + a "Right now" leading card).
  Waves 2–3 = Pickup board, incident logging.
