# Roles as SMART Daily Practice — unifying design brief

**Status:** design synthesis (2026-05-31). Grounded in 30 role cards, three teacher-model lenses, the live-block model (`docs/LIVE_BLOCK_CONTEXT.md`), and the shipping activity runtime (`activity_script.dart`, `this_or_that_screen.dart`, `content_bank.dart`).

---

## 1. The one principle

**A role is a SMART daily practice — and a kid's role and a teacher's practice are the same object, with the labels swapped.**

A role is exactly six things:

> **rules · a sequence · 3 habits · 3 artifacts · daily · measurable (SMART)**

- **rules** — the non-negotiables of how this role behaves ("one strand at a time," "decisions get an owner").
- **a sequence** — an ordered, paced flow you advance through. This is literally the teleprompter: a `ScriptedActivity` of `Phase`s walked by an `ActivityRun` cursor.
- **3 habits** — action *verbs* the role practices every day (gather · point the way · stay busy). What you *do*, not what you discuss.
- **3 artifacts** — the proof the role chooses to leave behind (a drawing, a photo, a recording). Self-chosen, not extracted.
- **daily** — low-ceremony, same shell every time. A rhythm, not an event.
- **measurable (SMART)** — scored against *its own* target, by the artifacts it left — never against a norm someone else wrote.

And it is **run host/present with a teleprompter:** the person holding the baton (`PacingKind.teacher`) drives from a **Control** view on their phone — Back / Reveal / Next — while the room watches a **Presentation** view. The phone is the remote; the structure is externalized so the loudest voice never sets the pace and the clock is neutral and visible to all.

That last clause is the load-bearing one. The teleprompter is a **justice device**: it does the including by *mechanism*, so no human has to police it and no one is judged for needing the rails. A kid who is slow, a teacher who thinks in writing — both are protected by the sequence, not by someone's goodwill. The kid model already proves this works on the floor; the teacher practice is the same engine pointed at adults.

---

## 2. Animal & nature role catalog

Curated and de-duplicated from 30 candidates down to **22** — keeping breadth of traits, dropping the weakest overlap in each cluster. (Cut, with the survivor that covers the same trait: **Seahorse**→Owl/Rabbit hold *focus*; **Ladybug**→Elephant holds *kindness/protect*; **Sea Turtle**→Oak holds *patience-slow*; **Squirrel**→Bee holds *gather*; **Eagle**→Giraffe holds *look-far*, Seed holds *courage*; **Mountain**→Whale holds *calm-breath*; **Flamingo**→Whale holds *steady-calm*; **Hummingbird**→kept, it's the only *curiosity* card. Capitalized `builds` values normalized.)

| Role | 3 habits (verbs) | 3 artifacts | builds |
|---|---|---|---|
| 🐜 **Ant** | carry something heavy · build a little tunnel · team up with a friend | tunnel-maze drawing · photo of the heaviest thing I carried · list of who I teamed up with | teamwork |
| 🐝 **Bee** | gather one thing at a time · buzz a dance to point the way · stay busy till it's done | photo of all I gathered · recording of my waggle-dance · drawing of the flowers I visited | diligence |
| 🦋 **Butterfly** | change step by step · move gently · brighten the room | drawing of my four growing stages · photo of my brightest colors · recording of my soft flutter | patience |
| 🕷️ **Spider** | spin one careful strand · wait quietly and watch · try again if it breaks | web-pattern drawing · photo of the web I built · note about the time I tried again | persistence |
| ✨ **Firefly** | make my own light · flash a signal to a friend · glow in the dark | drawing of my glow at night · recording of my blink-signal · note about when I shined | confidence |
| 🐬 **Dolphin** | check on a friend · call out kindly · leap with joy | drawing of my pod · photo of me helping a buddy · a friendly whistle I record | kindness |
| 🐙 **Octopus** | try a new way · change and adapt · reach with many arms | drawing of my puzzle + how I solved it · photo of what I fixed · list of 3 ways I tried | problem-solving |
| 🐳 **Whale** | take a deep breath · sing my song · move gently and big | drawing of my deep calm breath · a whale song I record · photo of my calm face | calm |
| 🦀 **Crab** | tidy my space · carry my home · hold on tight | photo of my tidy table · drawing of my shell home · list of what I put away | responsibility |
| 🦒 **Giraffe** | stand tall · look far · reach high | photo on tiptoes looking far · "tall as a giraffe" self-drawing · note naming one far-away thing I spotted | confidence |
| 🦊 **Fox** | look closely · listen quietly · figure it out | photo of a tricky thing I solved · "sneaky-clever plan" drawing · note with one good idea I had | problem-solving |
| 🐘 **Elephant** | stay gentle · help the little ones · remember a friend | photo of me helping a younger friend · drawing of my herd · note saying one kind thing I did | kindness |
| 🐰 **Rabbit** | listen with big ears · hold very still · notice tiny things | a sound I recorded after listening · drawing of one tiny thing most would miss · note about something small I noticed | focus |
| 🐺 **Wolf** | move with the pack · take turns · follow and lead | photo of my pack working together · a "howl" recorded with my team · note naming who I teamed up with | teamwork |
| 🦉 **Owl** | listen closely · turn to look · sit still and watch | drawing of the quietest thing I noticed · recording of a sound only I could hear · list of 3 things I spotted by waiting | focus |
| 🐧 **Penguin** | huddle close · take turns · waddle together | drawing of our huddle keeping warm · recording of our group waddle · written thank-you to someone who took a turn | teamwork |
| 🐦 **Hummingbird** | visit each thing · hover and look close · taste something new | drawing of the most colorful thing I found · photo of a new thing I tried · list of every spot I visited | curiosity |
| 🐦‍⬛ **Crow** | solve a puzzle · make a tool · remember a face | drawing of the tool I built · photo of the puzzle I solved · name of a friend I remembered to greet | cleverness |
| 🌳 **Oak Tree** | stand firm · grow a little · give shade | drawing of my tree with one new ring · photo of someone I sheltered · note naming one thing I grew at | patience |
| 🌻 **Sunflower** | turn toward the light · open wide · stand tall | photo of the sunniest spot I found · drawing of my face turned toward something good · a recorded cheer for a friend | optimism |
| 🌊 **River** | keep flowing · go around the rock · carry it forward | recorded "shhhh" flowing sound · drawing of my path bending around a rock · note about one hard thing I kept past | perseverance |
| 🌱 **Seed** | wait in the dark · soak it up · push up a sprout | drawing of my first sprout · photo of one new thing I tried for the first time · note naming what I'm growing into | courage |
| 🍄 **Mushroom** | connect underground · share what I have · clean up & recycle | drawing of my hidden threads reaching friends · photo of something I shared or tidied · a recorded "here you go" passing help | connection |

**Trait coverage** (so the deck has range): teamwork ×4, focus ×3, kindness ×2, problem-solving ×2, patience ×2, confidence ×2, courage ×2 — plus single-card anchors for diligence, persistence, calm, responsibility, cleverness, curiosity, optimism, perseverance, connection. Two families (20 animal / 3 nature kept) so a kid can be a *bee* one day and a *river* the next without it feeling like the same card reskinned.

**Shape note for the bank:** each card is exactly `{ name, emoji, kind, habits[3], artifacts[3], builds, oneLiner }`. Artifact slots come in three media types — **drawing / photo / recording** — which is not decoration: it's the contract the artifact-capture surface reads (see §4).

---

## 3. The teacher practice

The same object, authored *by the teacher, for the teacher*. The three lenses agree on the spine and split only on emphasis (one is permission-gated self-tracking, one is the meeting teleprompter, one is the inversion of measurement). Reconciled:

### The 3 staff habits

A teacher's practice has three daily action-verbs — and where a kid authors their own ("explore / share / create"), the team shares a fixed, low-friction trio that *is* the justice mechanism:

1. **HONOR** *(verb: honor)* — each morning the assistant surfaces **one** teammate's self-declared way of working as an ambient card ("Sam works best with the day's plan in writing by 8am"). The only interaction is a one-tap acknowledge → `entry(kind:'honored')`. You are not rating Sam; you are practicing the muscle of adapting to Sam. It **rotates** so over a week the whole team gets honored once — the existing `persona-audit` agent already knows how to find who's been skipped.
2. **NAME** *(verb: name)* — the adult artifact. Once a day, capture or receive one concrete kudos tied to *how* someone worked: "Maria spotted the meltdown before it started because she watches transitions closely — that's her ADHD, and it kept a kid safe." Stored `entry(kind:'kudos', subject=teammate)`, inheriting `scheduleBlockId` from the live block so it ties to real context. Reframes difference-as-deficit into difference-as-contribution, in the team's own record.
3. **FLAG, DON'T FIX** *(verb: flag)* — the habit with teeth. Anyone can flag, in two taps (optionally anonymous to the team, visible to the host), a moment where someone's declared way of working was overridden — "today's all-staff put Sam on the spot for a verbal answer." Creates `entry(kind:'honor_gap')`, names no culprit, and routes to the host to **repair the sequence, not discipline a person.** This is the inverse of a system that catches when the *person* failed the team: it catches when the *team* failed the person.

### "Respected, not judged = justice" is STRUCTURAL

Not a value statement bolted on top — encoded in the data shape and in *what columns deliberately do not exist*:

- **Self-authored, no approval gate.** A teacher declares "this is how I work best" by editing a **Way of Working** card on their *own* member row — stored in the existing `members.capabilities` JSONB (the viewer lens already reads it; **no migration**). There is no "request accommodation → await manager decision" workflow, because routing self-knowledge through a manager's permission is exactly the judgment being rejected. Self-authorship *is* the justice.
- **The default is to honor; overriding costs the tap.** This is the live-block asymmetry (`R0 — it decorates; it never gates`) inverted into the social layer. A Way of Working renders as a *pre-applied default* on other people's surfaces — open the meeting builder and Sam's written-processing preference is already applied ("Sam will get this agenda tonight + a written slot"). Honoring is silent and free; **overriding is one tap and leaves a logged `honor_gap` trace.** The silent default is to adapt; the thing that costs you is failing to.
- **No punitive column exists.** The schema for practice evidence (`entries` with the new kinds) has no `score`, `flag`, `deduction`, `manager_note`, or `compliance` field — only additive, self-authored evidence. *You cannot use a tool to punish if the tool has no place to record a punishment.* The missing column is the guarantee — the same way `certifications.dart` has evidence + expiry but no "fail" state.
- **The person reads first.** Every number about a teacher is visible to that teacher *before* anyone with director caps can see it (the Devon co-parent read-state pattern, pointed at staff). Sharing is per-practice, **opt-in, previewable, revocable** (reuse the signed-export "this is exactly what they'll see" confirm). RLS gates reads on `member_id = caller` until the owner flips a share cap — the inverse of the relax-read pattern. **A teacher can run their practice forever and never share it, and the app is fully useful** — self-knowledge is the product; the org rollup is the optional secondary.
- **The Way of Working has a fixed, plain-language shape** — each field decorating a *consumer's* surface, never flagging the person: `processingStyle` ("I think in writing / out loud / after sleeping on it") drives whether the meeting assistant sends *you* the agenda the night before; `transitionNeed` ("5 min between blocks") makes Today stop auto-nudging you and grants the live-block 15-min grace; `commsWindow` ("batch at 3pm") holds non-urgent staff pings; `bestHours` / `hardNo` are advisory chips the scheduler and substitute-handoff read; `freeText` is one sentence rendered **verbatim, never normalized**. It's PII-adjacent self-disclosure, so it follows the children's-data posture: never in logs, space-scoped RLS, and **owner-set per-field visibility** (team / director-only / private).

### The meeting assistant — checklist + sequence-of-time teleprompter

A staff meeting **is a role the team plays for 30–60 minutes.** It maps cleanly: `rules → ground rules` · `sequence → timed agenda` · `3 habits → SURFACE / DECIDE / CLOSE` · `3 artifacts → Decisions(owner) / Action items(assignee+when) / the Record` · `daily → recurring standups & handoffs` · `measurable → did everyone get a turn? did we finish on time? did every decision get an owner?`. It is **literally a `ScriptedActivity` whose `Phase`s are agenda items**, paced `PacingKind.timer` with a teacher-tap override, driven by the same `ActivityRun` cursor and the same Presentation/Control split as `ThisOrThatScreen`.

**Concrete in-meeting UI** (the two halves the user named — "a checklist of what is needed, like an assistant, and a sequence of time"):

```
  ROOM SCREEN (Presentation)              FACILITATOR PHONE (Control)
┌──────────────────────────────┐    ┌─────────────────────────────────┐
│ Ground rules:                │    │ ▸ WHAT-IS-NEEDED (collapsible)   │
│  one voice · owners · no      │    │   ☐ Cover Maya's room Thursday   │
│  relitigating                 │    │   ☑ Field-trip slip count         │
│                              │    │   ☐ Sign off close-of-day routine │
│ ┌──────────────────────────┐ │    ├─────────────────────────────────┤
│ │  ITEM 3 of 6             │ │    │  ROOM MAP (honor chips)          │
│ │  Snack rotation          │ │    │   Sam · written input submitted  │
│ │                          │ │    │        — read it, don't cold-call │
│ │      ◷  4:32             │ │    │   Maria · hard-stop 3:15          │
│ │   (amber ring at T-0:30) │ │    ├─────────────────────────────────┤
│ └──────────────────────────┘ │    │  [ Prev ]  [Capture decision]  [Next]│
│  • Round mode: Sam ● (90s)    │    │            ↑ chameleon middle btn │
│    Maria · Jo · (passed) Lee  │    │   discussion → Capture decision   │
└──────────────────────────────┘    │   SURFACE → Next turn             │
                                     └─────────────────────────────────┘
```

- **The checklist (the "assistant").** A collapsible **WHAT-IS-NEEDED** rail, seeded before the meeting and tick-able during it — the staff parallel of a role's "rules + 3 artifacts." Each row is one tap to resolve; resolving auto-prompts the DECIDE capture (decision text via the existing **Deepgram** mic + an **owner** chip reusing `PersonAvatar`). **Unresolved rows at the final phase auto-flow to the parking lot — nothing needed silently evaporates.** A per-phase READY check (pre-read attached? owner present? materials linked?) shows a soft amber "not ready — park or proceed?" — **never a hard block** (live-block R0: it decorates, it never gates).
- **The sequence-of-time (the teleprompter).** Presentation shows the current item big with a live countdown ring; Control shows `Prev / [chameleon action] / Next` exactly like `_ControlBar`'s Back / Reveal / Next. A soft chime + amber ring at T-0:30 keeps time so **no human is the clock-cop** — time pressure comes from a screen everyone sees, not from the senior person sighing. Overrun is allowed (the live-block **15-min grace**, never a hard cut): it shows "+2:00 over" and offers "borrow from next / extend."
- **The one genuinely new bit — Round mode (SURFACE).** Flip it on and Presentation shows a **roster ring**, advancing one name at a time with a soft ~90s timer; the ring **won't reach anyone's second turn before everyone's had a first.** **Pass** and **Park it** are first-class, neutral chips — "passed / will circle back," **never a red X.** This is the surveys feature's "one prompt over a roster, one at a time" engine reused as a turn-ring. It is the *literal mechanism* of different ways of working being respected: the quiet / slow / written-processor is **guaranteed airtime by the machine**, not by someone remembering to ask.
- **Async-first inclusion.** Before the meeting (the night prior), the assistant reads every attendee's Way of Working and pushes the agenda + decision items to anyone whose `processingStyle` is "in writing"/"sleep on it," with a written-response field per item — so **their input lands before the room convenes and is read aloud as theirs** (the kid model's "the quiet kid's answer still counts"). Attendees with a `transitionNeed` get the meeting auto-scheduled to start 5 min after their prior block.
- **CLOSE writes itself.** The final phase is a **Wrap card** (parallel to `_WrapSlide`): auto-assembled Decisions / Action items / Record (attendance + who-spoke-or-passed as *coverage, never a score* + parking lot). `Save & send` writes one `EntryKind.meeting` row and posts the summary to the existing **messages** thread; action items can fan out as **Tasks**. The parking lot stamps forward to seed the **next** instance of this recurring meeting (`recurrenceId`) — so every standup inherits last standup's unfinished business and any honored adaptation persists. *No one types minutes; the sequence wrote itself,* exactly like the live-block day tags itself into a timeline.

### Measurable / SMART — WITHOUT surveillance

The line is drawn by **what we store and what we refuse to store**, enforceable in code, not by promise:

1. **The subject of measurement is inverted.** You measure the **team's habit of honoring**, never the individual's conformance. The kid measures against the kid's *own* target; the staff model measures the *team* against its *own* promises to each person. All metrics are a `GROUP BY` over the three habit-entry kinds — zero new tracking plumbing:
   - **HONOR COVERAGE** — "every teammate honored at least once this week." The gap it surfaces is *"who has the team not adapted to lately"* — a failure of the **group**, shown to the group.
   - **HONOR-GAP TIME-TO-REPAIR** — when a flag is raised, how fast did the *sequence* change (was Sam's written slot added next time)? Measures the org's responsiveness, **not Sam.**
   - **KUDOS DISTRIBUTION** — is strength-naming spread, or pooling on a favored few? A skew is a justice signal about the team's *attention*, never a ranking of people.
2. **Counts up, never down.** Presence, never absence — "you noticed 14 small wins this week, strongest habit *slow down*," never "missed 3 of 7 days." **No breakable streaks** (a broken streak is a small daily punishment); a "recent rhythm" sparkline that only ever adds. SMART targets are the person's *own typed intent*, so "achieved" is self-relative.
3. **Capture is a byproduct, never a report.** Evidence auto-stamps to the live block at write time (live-block auto-tag, **zero deliberate self-reporting** — a form you fill *for someone else* is the felt essence of surveillance). Computed locally in Drift, offline-first, **never a row-level analytics event** (the CLAUDE.md privacy rule: event-level, never row-level).
4. **Hard guardrails, stated as build invariants** so a future contributor can't "helpfully" add them: no per-person talk-time leaderboard, no word-count / engagement score, no manager-only dashboard the person can't see, no cross-meeting per-individual dossier, no export that re-shapes participation into a performance signal. **The only red/amber the system shows is "the team owes someone a habit it skipped."** The dashboard can fail the team; it is structurally incapable of failing the person. *That asymmetry is the justice.*

---

## 4. Maps onto what exists

The runtime is already built. This brief is **mostly relabeling, plus 2–3 small primitives.** Verified against the code:

| This brief needs… | …already shipping as |
|---|---|
| **The role catalog / agenda templates** | `content_bank.dart` — `ContentItem { kind, fingerprint, payload }` behind a source-agnostic `ContentSource`. A role card is one `ContentItem(kind:'role', payload:{habits, artifacts, builds, …})`; a meeting template is one `ContentItem(kind:'meeting_script', …)`. The `fingerprint` is the **de-dupe key** that lets the §2 cull live in data. DB-backed bank drops in behind the same interface later. |
| **The host/present teleprompter** | `this_or_that_screen.dart` — the Presentation (room) / Control (phone) two-view split, `_ControlBar` (Back / Reveal / Next), `_WrapSlide`. Reused verbatim for both kid roles and staff meetings. |
| **The sequence + who-holds-the-baton** | `activity_script.dart` — `ScriptedActivity → List<Phase>`, `ActivityRun` cursor (`advance()` / `restart()` / `isAtEnd` / `index`), `PacingKind` (teacher / timer / perLearner / nonStop). A meeting is a `ScriptedActivity` paced `timer` + teacher override. |
| **Artifacts / showcase** | Photos via Storage + the `entries`/`attachments` model + the deferred **showcase/growth-arc** compilation. A role's 3 artifacts feed the same reel; a teacher's year-end becomes a reel of *how their way of working showed up*. |
| **Per-phase turn-taking ring** | the **surveys** feature's "structured prompt over a roster, one at a time" engine — relabeled as the Round-mode ring. |
| **Live-block tie + 15-min grace + auto-recap** | `docs/LIVE_BLOCK_CONTEXT.md` + the `scheduleBlockId`-on-`entries` keystone column. Habit-marks, kudos, and meeting items inherit the block for free; recaps are a `GROUP BY` on `entriesForBlockProvider`. |
| **Self-owned, opt-in, no-approval data home** | `members.capabilities` JSONB (Way of Working — **no migration**; viewer lens already reads it) + the `certifications.dart` self-attested / no-fail-state contract. |
| **Free-text authoring of habits/rules** | `InlineEditableText` (Wave 174 formless CRUD); the schedule already went free-text in Wave A — so no normative template is forced on a teacher. |

**The NEW primitives — only three:**

1. **"3 artifacts per role"** — a tiny typed contract on a role's payload: `artifacts: [{slot, media: drawing|photo|recording, prompt}]` ×3. It's the bridge between a role card and the capture surface (the card tells the capture flow *what three things to leave behind, in what medium*). For staff meetings the three slots are fixed: Decisions / Action items / Record.
2. **"SMART daily record"** — extend `EntryKind` (today a string-constant class with just `observation`) with the additive, **never-punitive** kinds: `role_artifact` + `habit_mark` (kid & teacher self-evidence), and `honored` / `kudos` / `honor_gap` / `meeting` (staff). All ride the **existing** `entries` table + `scheduleBlockId`; the insights provider computes presence-only `GROUP BY`s. *No new sync table for v1.*
3. **The "meeting runner"** — a thin shell that builds a `ScriptedActivity` from a `meeting_script` template, mounts the existing two-view teleprompter, overlays the WHAT-IS-NEEDED checklist + the Round-mode ring, and emits the Wrap card as one `EntryKind.meeting` write. New screen at `/meetings/…` + slash command `/meet {agenda}` + omnibox/drawer wiring (the four-surface rule; `feature-mapper` will verify).

---

## 5. Build seed

The smallest slices that prove each feel.

### (a) Animal role cards — on the deck, kid-handheld, printable

The role card is the kid-side analog of the activity card — *the deck is the catalog.*

1. **Seed the 22 roles into the content bank** as `ContentItem(kind:'role', fingerprint: name.toLowerCase(), payload:{emoji, habits[3], artifacts[3], builds, oneLiner})`. Pure Dart seed list, same shape as the This-or-That seed — no DB, no migration. This is the entire catalog and the de-dupe source of truth.
2. **One `RoleCard` widget** — `FeatureCard`-tone, big emoji, the one-liner, the three habit verbs as chips. Tappable. This is what shows on the deck, what a kid holds on the handheld, and what prints. **Printable reuses the existing PDF path** (`vehicle_qr_pdf.dart` / exports pattern): one card per page, emoji + one-liner + the 3 habits + 3 artifact prompts, in the same squircle-and-wordmark system as the role cards already on the table.
3. **"Today I am a ___" pick → a `habit_mark` per habit.** A kid (or staff-curated) picks a role for the day; the three habits render as a tiny 3-item checklist with generous kid-mode tap targets. Each tap writes `entry(kind:'habit_mark')` — auto-stamped to the live block (zero extra taps, the live-block loop). That's the whole daily loop: *pick a role → do the 3 things → it's recorded → it feeds the reel.* Artifact capture (drawing/photo/recording → the showcase) is slice two.

> First slice that proves the feel: **seed + `RoleCard` on the deck + the "Today I am" pick writing 3 `habit_mark`s.** If a kid lights up picking a card and the day quietly records itself, the printable, the artifact capture, and the showcase reel are mechanical extensions of the same `ContentItem` + `EntryKind`.

### (b) Teacher meeting-assistant

1. **The meeting runner over the existing teleprompter.** New route `/meetings/run/:id`. Build a `ScriptedActivity` from a hard-coded **Daily Standup** template (5 phases, `PacingKind.timer` + teacher override). Mount `ThisOrThatScreen`'s Presentation/Control split as-is. Phone = Control (`Prev / Capture decision / Next`), room/laptop = Presentation (item big + countdown ring). **This alone is a working time-boxed agenda walker** and reuses 100% shipped code.
2. **The chameleon middle button → DECIDE capture → `EntryKind.meeting`.** On a discussion phase the middle button is "Capture decision": one tap → decision text (Deepgram mic) + owner chip (`PersonAvatar` Member picker). Optimistic local Drift write, no awaited network. The Wrap card on the final phase is a `GROUP BY` over the meeting block's entries, rendered in a `SectionCard` that hides when empty → `Save & send` to the messages thread.

> First slice that proves the feel: **the Daily Standup teleprompter + one-tap DECIDE capture + the auto Wrap card.** That's the "checklist of what's needed + a sequence of time" the user asked for, on one path. If a standup ends with a written record nobody typed and every decision has an owner, then Round mode (the roster ring), the WHAT-IS-NEEDED rail, the Way-of-Working honor chips, and the three staff habits all hang off the same runner and the same `entries` kinds.

---

**Save as:** `docs/ROLES_SMART_PRACTICE.md`.

**Relevant files (all absolute):**
- `/Users/jardinefaner/differentworld/lib/features/activity_runtime/activity_script.dart` — `ScriptedActivity` / `Phase` / `ActivityRun` / `PacingKind`
- `/Users/jardinefaner/differentworld/lib/features/activity_runtime/this_or_that_screen.dart` — Presentation/Control teleprompter (`_ControlBar`, `_WrapSlide`)
- `/Users/jardinefaner/differentworld/lib/features/activity_runtime/content_bank.dart` — `ContentItem` / `ContentSource` (the role + meeting-script catalog home)
- `/Users/jardinefaner/differentworld/lib/features/entries/entries_providers.dart` — `EntryKind` (extend with the new additive kinds)
- `/Users/jardinefaner/differentworld/lib/features/certifications/` — self-attested, no-fail-state contract to mirror
- `/Users/jardinefaner/differentworld/lib/shared/widgets/inline_editable_text.dart` — formless authoring of habits/rules
- `/Users/jardinefaner/differentworld/docs/LIVE_BLOCK_CONTEXT.md` — the ambient-tie + grace + auto-recap model this builds on
