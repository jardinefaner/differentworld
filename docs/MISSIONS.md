# Missions — real jobs, real evidence

The design for [VISION.md](VISION.md) **#16**.

> "roles that actually require real life evidence... helping maintain
> supplies, helping clean... their manuals, how they're supposed to be put
> away... small missions they could truly do if they want to save
> progress... equipment manager, lunch/snack helper... what are the rules,
> what they look like, and actions they could practice"

## Missions vs Role Cards — the key distinction

Two complementary systems that share one card grammar:

| | **Role Cards** (#8) | **Missions** (#16) |
|---|---|---|
| Nature | Imaginative — *be* a Bee, an Astronaut | Real — *do* a job |
| Habits/Actions | Metaphorical ("gather one thing at a time") | Literal ("count the balls back in") |
| Evidence | Creative (a drawing of my glow) | **Real** (a photo of the tidy bin, a count) |
| Where it lives | Compiled catalog, same everywhere | **Per-program data** — each program's own jobs + manual + places |
| Outcome | Explore who you could be | **Prove** who you are; the gear actually got put away |

Role Cards let a kid *try on* a trait. Missions let them *demonstrate* it,
for real, and bank the proof. A kid who keeps choosing Cleanup and
Equipment missions is building **real evidence** for the "Doer / Protector"
identity (#2) — not a sticker, a track record.

## Anatomy of a mission — "what they look like"

A mission card carries:

- **Identity** — a name + an icon + the trait it **builds**.
  ("Equipment Manager 🏀 · builds responsibility")
- **The why** — one line on why the job matters.
  ("Our gear lasts when someone looks after it.")
- **The rules (the manual)** — *how* it's done and *where things go*. This
  is the SOP the user means by "their manuals, how they're supposed to be
  put away." Program-specific ("balls live in the bin by the gym door").
- **The actions** — the real, practiceable checklist (3–5 steps).
- **The evidence** — what proof to leave when done: a **photo**, a
  **count**, a **note**, or just a **check**.
- **The links** — which real things it touches: **supplies** (#15) it
  maintains, the **location** it tends. So the manual is *live* — "balls"
  is the actual supply row, "gym bin" the actual location.

The card face reuses the Role-Card layout (icon · name · builds · a
checklist), so it already feels native.

## Starter catalog — "the rules, and actions they could practice"

Shipped as **editable templates** a director adds + tailors (each program's
manual differs). Two in full; the rest are the same shape. Tagged by age
band (4–6 / 7–9 / 10–12) like discussions, so a 5-year-old gets Line Leader,
not Supply Keeper.

### 🏀 Equipment Manager — *builds responsibility*  (7–12)
- **Why:** Our gear lasts when someone looks after it.
- **Rules (manual):** Balls live in the bin by the gym door. Jump ropes
  coiled on the hook. Count before and after. Anything broken → tell a
  counselor, don't throw it out.
- **Actions:** ① Hand gear out fairly ② Count it back in ③ Wipe / coil /
  stack ④ Put it where the manual says ⑤ Report missing or broken.
- **Evidence:** photo of the tidy bin + the final count.
- **Links:** supplies (balls, ropes) · location (gym bin).

### 🍎 Snack Helper — *builds service & care*  (4–12)
- **Why:** Everyone eats when snack runs smoothly.
- **Rules (manual):** Wash hands first. One each until everyone's had a
  turn. **Check the allergy list — that table is separate.** Wipe tables
  after. Leftovers back in the labeled bin.
- **Actions:** ① Wash hands ② Set out napkins + cups ③ Hand out one each
  ④ Wipe the tables ⑤ Pack leftovers + count.
- **Evidence:** photo of the set / cleaned table.
- **Links:** supplies (snacks, napkins) · location (snack area) · the
  allergy list (a safety gate — staff-supervised).

### The rest (same shape)
- **🧹 Cleanup Crew** — responsibility/teamwork. *Chairs up, floor clear,
  everything in its home.* ① chairs up ② pick up floor ③ return items
  ④ scan for stragglers ⑤ high-five. Evidence: before/after photo.
- **📦 Supply Keeper** — diligence. *Restock the art cart; flag what's
  low; caps on, lids on.* Evidence: restocked-cart photo + items flagged.
  **Links straight to Supplies** — this is the human behind the low-stock
  flag (#15).
- **🚸 Line Leader** — leadership. *Walking feet, wait at every door, count
  heads.* Evidence: the headcount (ties to the existing headcount data).
- **👋 Greeter** — kindness/connection. *Welcome each arrival by name; show
  new kids the cubbies, bathroom, the rules.* Evidence: who you welcomed.
- **📚 Library Keeper** — order/care. *Books spine-out by section; damaged
  ones to the repair bin.* Evidence: tidy-shelf photo.
- **💡 Lights & Doors** — stewardship. *Lights off leaving a room; doors
  held for the line, closed after.* Evidence: a check per transition.
- **♻️ Recycle Captain** — stewardship. *Paper blue, cans green, rinse if
  sticky.* Evidence: sorted-bins photo.
- **🌱 Plant & Pet Caretaker** — care/consistency. *Finger-test the soil;
  measured scoop for the pet; fresh water.* Evidence: photo + a note on how
  they're doing.
- **🤝 Peace Buddy** — empathy. *Help friends use words; offer the calm
  corner; get a counselor for big problems.* Evidence: a note.

## Coordination — "who has which job today"

A **mission board**: today's open missions and who holds each. Assignment
is **opt-in** ("if they want") with a staff confirm:

- A kid **claims** a mission (or staff assigns it). Staff confirms.
- The board shows the day's roster — "Equipment → Maya · Snack → Jordan" —
  so the room coordinates at a glance.
- Missions can rotate (per-day or per-week) so jobs are shared over time.

## Save progress — "if they want to save progress"

Doing a mission **leaves a record**:

1. Kid opens their claimed mission → sees the manual + the checklist.
2. Works the steps (real life), ticks them off.
3. Marks done + leaves the evidence (snap the bin / enter the count / a
   note).
4. That writes an **entry** (kind `mission`) + an **attachment** (the
   photo) — the *same* data the growth book + showcase already read (#1).

Over time those completions become a **track record**: "this term Maya was
Snack Helper ×8, Equipment Manager ×3." Streaks + a few **badges** make it
feel like progress, not a chore chart. And it's **real evidence for the
identity card** (#2) — the archetypes stop being a quiz and start being
earned.

## Data model

Per-program data (unlike the compiled Role Cards), so:

- **`missions`** (catalog, synced, space-scoped): `id`, `space_id`, `name`,
  `icon`, `tagline`, `why`, `builds` (trait), `rules` (the manual text),
  `actions` (jsonb — ordered step strings), `evidence_kind`
  (photo/count/note/check), `location_id` (nullable → locations),
  `supply_ids` (jsonb — supply ids it touches), `age_bands` (jsonb),
  `is_active`, `sort`, timestamps. Seeded from the starter templates,
  director-editable.
- **`mission_assignments`**: `id`, `space_id`, `mission_id`, `subject_id`
  (the kid) *or* `member_id` (staff), `period` (date or week key),
  `status` (open/claimed/done), `assigned_by_member_id`, `completed_at`,
  timestamps.
- **Evidence + completion: reuse `entries` + `attachments`** (kind
  `mission`, payload `{mission_id, assignment_id, count?, note?}`). No new
  evidence table — it flows into the growth-arc data we already have. The
  track record is *derived* by counting these entries per subject; no
  badges table needed for v1.
- **Manuals** live on the mission's `rules` (the SOP). A location/supply
  could later carry its own "how to put away" note, but v1 keeps the
  manual on the mission.

All the usual invariants: uuid PKs client-side, RLS by space, syncs via
`by_space`; mission photos → Storage (path on the attachment), never bytes
over PowerSync.

## Build slices

1. **The mission catalog.** `missions` table + DAO + a Settings library
   (mirrors Supplies exactly) + seed the starter templates. The cards
   render (identity · why · rules · actions · builds). *Unblocked,
   solo-testable.*
2. **Take a mission + leave evidence.** Claim/assign → the kid's
   checklist + manual → mark done → photo/count/note → writes an `entry` +
   `attachment`. The "truly do + save progress" payoff. (Kid-mode surface.)
3. **The mission board.** Today's roster + who holds each — the
   coordination view.
4. **Progress.** Per-kid track record + streaks/badges → feeds the growth
   book (#1) and the identity card's evidence (#2).

## Open questions (decide before slice 2)

- **Who assigns?** Proposed: **kid-claims, staff-confirms** ("if they want"
  = opt-in), with staff able to assign directly too.
- **Cadence:** per-day claim vs weekly rotation (support both; default
  per-day).
- **Evidence required?** Per-mission: some need a photo, some a count, some
  just a check. Don't force a photo where a check is enough.
- **Who can hold a mission — kids, staff, or both?** Both (a counselor can
  be the Equipment Manager on a thin day); the card is the same.
- **Safety gate:** some missions touch real-world risk (allergy table,
  sharp/cleaning supplies). Those are **staff-supervised** and flagged on
  the card; missions are kid-*doable*, never kid-*alone* for anything with
  a hazard.
- **Where kids do it:** the kid-mode surface (claim + checklist + evidence)
  — ties into the kid-journal / Action Words direction.

## Why this is the keystone the other dreams were waiting for

Missions are where four threads converge: **Supplies** (#15) get
maintained by a real person; **Locations** get tended; the **growth book**
(#1) fills with real evidence; and the **identity card** (#2) earns its
archetypes instead of asserting them. It's the most "Different World" idea
in the set — software that sends a kid *back into the room to do something
real*, then quietly remembers that they did.
