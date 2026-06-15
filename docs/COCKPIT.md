# The cockpit — `/now`, the clock-driven surface

The build map for the 2026-06-15 vision (docs/VISION.md → *"the app is a
clock that knows your kids"*). The **why** lives in VISION.md; this is the
**how**: the beat model, the settled forks, and the slice plan.

One line: **the home surface becomes ONE card that the clock selects.** You
never navigate; the current moment is shown, everything else recedes to a
pull-down. This is the finished shape of the 2026-06-14 "context is the
navigation" dream — `contextLeadProvider` already chose the *moves* for a
moment; the cockpit promotes that choice from *a card on Today* to *the whole
surface*.

---

## The beats

A **beat** is a state of the one surface. The engine maps the day to a beat;
the surface renders it by **delegating to a surface that already exists** — the
cockpit is a *frame*, not a rebuild.

| Beat | When (auto) | Renders by delegating to | Status |
|---|---|---|---|
| `gettingReady` | `DayPhase.prep` | the schedule preview (`/schedule`) | slice 1 |
| `goodMorning` | `DayPhase.arrival` | greet + journey + mood + "pick today's verbs" (verb pick is the morning's primary action) | slice 1 (greet+mood); verb-pick inline = slice 2 |
| `now` | `DayPhase.program` + a live block **or** a gap | `contextLeadProvider` (already leads run/observe/attendance/headcount). A world block IS "verb hour" — the lead already says "Run the session". | slice 1 |
| `fieldTrip` | any phase, live block `kind == field_trip` | the trip cockpit (vehicle checkout + roster + headcount) — the lead's trip branch | slice 1 |
| `reveal` | the closing window (see fork ③) | `BeatPresenter` / `/play-today` / growth arc — the dark glowing stage | surface exists; **auto-trigger = slice 2** |
| `pickup` | `DayPhase.pickup` | the release board (`/pickup`) | slice 1 |
| `send` | `DayPhase.closed`, with sendable kids | per-kid parent message (`buildParentMessage`) + copy | slice 1 (entry); inline composer = slice 2 |
| `closed` | `DayPhase.closed`, nothing to send | a quiet "that's the day" rest state | slice 1 |

The mapping is a **pure function** — `computeCockpitBeat(...)` over primitives
(phase, live-block kind, role, has-world, sendable count) — so it's unit-tested
without Riverpod, exactly like `computeContextLead`. `cockpitBeatProvider` is
the thin adapter that reads `dayPhaseProvider` + `liveBlockProvider` (+ the
room override) and calls it.

---

## Settled forks

**① Auto-advance vs one-tap-next → BOTH, auto is the default, never a cage.**
The surface shows the clock's beat on open (auto). The 2026-06-14 law holds:
*a wrong inference that HIDES the tool you need is the only real failure.* So
the beat is always **overridable** — a small "beat rail" lets you step to any
beat by hand (the same affordance the present spine already has). No silent
lock. The clock *suggests*; the teacher can *override*; the omnibox is still
the full palette underneath.

**② Pull-down is the curiosity bar, NOT navigation.** A downward drag from the
top reveals the five Layer-2 destinations — Today · Kids · Activities ·
Collection · Patterns. It's a *gesture*, opt-in, that most days you never use.
Implemented as a top-anchored draggable panel (not a nav bar, not the drawer).
The drawer + omnibox still exist as the escape hatches; the curiosity bar is
the "wade in" affordance the ocean metaphor calls for.

**③ Off-schedule bends the clock — the live block wins over the phase.** A
field trip at 10 a.m. is not "now / program time" — it's the trip cockpit. Rain
day, nap, an assembly: whatever block is *live* overrides the time-of-day beat
(this is already how `computeContextLead` resolves — live block first, phase
fallback). The **`reveal` window** is the one beat the clock can't infer
generically (no fixed end-of-day across programs/verticals): slice 1 makes it a
**manual "start closing" beat** you step to; auto-triggering it needs a
per-program end-of-day signal (the last block's end, or a director tap) — fork
left open, tracked as slice 2.

**④ Layer-3 conductor = a web target, not the phone.** The deep layer (weekly
planning, monthly reports, the end-of-summer per-child PDF) is a **separate
laptop surface**, reached only on web/desktop — it never competes with the
phone's Layer 1. It reuses the same providers + the export pipeline (`exports`
table, the summer book). Not in slice 1; it's its own wave.

**⑤ Promotion path: `/now` proves itself, THEN becomes home.** The cockpit
ships as a **new opt-in route** (`/now`, an immersive surface that hides the
shell chrome via `cockpitImmersiveProvider`, mirroring `castImmersiveProvider`).
The current Today screen stays exactly as-is. Once the cockpit feels right on a
real device, a single setting (or the redirect) makes `/` resolve to it. This
de-risks a rewrite of the primary screen into an additive, reversible step.

---

## Slice plan

- **Slice 1 (this wave) — the foundation, wired end-to-end.**
  `computeCockpitBeat` + `cockpitBeatProvider` (+ unit test); the
  `NowCockpitScreen` at `/now`, immersive, rendering the current beat by
  delegating to the existing surfaces above, with the beat rail (override) and
  the pull-down curiosity bar; the four discovery surfaces wired
  (router / omnibox / drawer / FEATURES.md). Today untouched.
- **Slice 2 — flesh the program-specific beats inline.** The morning verb-pick
  inline (not a route hop), the `send` composer inline, the `reveal`
  auto-trigger (the closing-window signal).
- **Slice 3 — Layer-3 conductor.** The laptop dashboard: weekly planning view,
  the end-of-summer per-child report → PDF.
- **Slice 4 — promotion.** A setting (or redirect) that makes the cockpit the
  default home; Today demoted to a Layer-2 curiosity destination.

## Invariants this surface must keep

- **Offline-first**: every beat reads from Drift; nothing here calls Supabase.
- **One-thumb**: tap / swipe / drag only; no beat requires typing except the
  one parent-message sentence (slice 2).
- **The emotional arc**: warm morning → utilitarian now → dark/glowing reveal →
  quiet send. Colour is chosen by the *moment* (the `ContextTone` precedent),
  never hardcoded on a themed surface; the reveal is a raw-canvas immersive
  stage (THEME_ADHERENCE allows its dark palette).
- **Never a cage** (fork ①): the clock suggests, the teacher overrides.
