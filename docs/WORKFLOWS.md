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

1. **Time‑aware Today** ✅ *shipped (wave 1)* — a `DayPhase` derived from the
   clock (afterschool defaults, later program‑configurable) + a leading
   **"Right now"** card that switches by phase: arrival → check‑in, program →
   schedule, pickup → the board. Leads the eye to surfaces that already exist;
   no new data layer. `lib/features/today/` (`dayPhaseProvider`, `_RightNowCard`).
2. **A real Pickup board** ✅ *shipped (wave 2)* — a dismissal board
   (still‑here · authorized · one‑tap release · undo) at `/pickup`. A release is
   `entries.kind='departure'` — a separate axis from attendance, no new table.
   `lib/features/pickup/pickup_board_*`. *Deferred:* late‑pickup timers + push.
3. **Structured incident logging** ✅ *shipped (wave 3)* — a first‑class typed
   incident record (type · narrative · action · family‑notified) at `/incidents`,
   distinct from observations. `entries.kind='incident'`, no new table.
   `lib/features/incidents/`. *Deferred:* photos, per‑subject history, PDF/CSV
   export.

## Status

- **Map:** this doc.
- **Build:** all three highest‑leverage gaps **shipped** — wave 1 time‑aware
  Today, wave 2 Pickup board, wave 3 incident logging. Each reused the synced
  `entries` table (or pure clock derivation), so none needed a new table /
  migration / PowerSync‑dashboard deploy. Remaining opportunities in the table
  above (day‑open brief, face‑aligned check‑in, "run this block", close‑the‑day,
  substitute handoff) are the next tier.

### Design note — "day's end" is per‑person, not a program close time

The first cut of close‑the‑day / late‑pickup assumed a single program close
time (the afterschool `DayPhase` boundary). **That's wrong:** day's end is
**different for each child and each teacher**, driven by their individual
**clock‑in / departure** times (and, eventually, each child's *expected* hours
on file). The raw material now exists — clock‑in = the attendance `present`
timestamp (`attendance_records.recorded_at`), clock‑out = the pickup
`departure` entry's `recorded_at` — but "late" / "still here" relative to an
*expected* departure needs a per‑child schedule we don't store yet (enrollment
hours / a daily expected‑out time). So **closeout + late‑pickup are deferred**
until that per‑individual expected‑hours model lands, rather than shipping a
program‑wide approximation. The Today *arrival progress* (wave 5) and the
pickup board (wave 2) are the adoption‑independent pieces that don't need it.
