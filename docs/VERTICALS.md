# Where everything fits — the two axes of portability

The system was built to travel. The question "where else does everything
fit?" has a precise answer, and it's **two different axes**, because the app
is two layers stacked:

1. **The engine** — Space / Member / Group / Subject / Entry, plus the
   daily-ops loop (attendance, entries, roster, messages, sync, the
   readiness check). Domain-agnostic by construction
   ([NAMING.md](NAMING.md)).
2. **The experience** — the eleven primitives ([PRIMITIVES.md](PRIMITIVES.md))
   and the curriculum built on them (verbs, worlds, the RPG, Big Thinking,
   the forge). Universal *atoms*, childcare-specific *content*.

Each layer is portable, but to a **different set of places.**

---

## Axis 1 — the engine → operational verticals (LIVE in code)

`lib/core/vertical/labels.dart` already defines five label sets, and
`verticalLabelsProvider` already switches on `space.caps[vertical]`. The
operational backbone fits any of these **today**, with only labels changing:

| Vertical | Space | Group | Subject (the one you serve) | Entry |
|---|---|---|---|---|
| **Childcare** | Program | Classroom | Child | Observation |
| **Construction** | Company | Crew | Project | Daily update |
| **Healthcare** | Clinic | Department | Patient | Chart note |
| **Hospitality** | Restaurant | Section | Guest | Order note |
| **Manufacturing** | Plant | Line | Work order | Defect log |

What ports for free: who's here (attendance), the work-log stream
(entries), the roster, the team, messages, the sync layer, RLS, the
readiness check, the omnibox. A clinic charting patients and a plant
logging defects are *the same engine* with different nouns.

**What's real / what's the gap:**
- ✅ The five label sets + the switch (`verticalLabelsProvider`).
- ⚠️ **No picker** — a director can't yet *set* `SpaceCaps.vertical`. The
  switch reads it; nothing writes it. (Migration-free to add — it's a
  `capabilities` cell + the existing `setStringCap`.)
- ⚠️ **The curriculum layer isn't gated.** Flip a space to `healthcare`
  today and the engine re-labels (Clinic/Patient) but the verb-pick, the
  worlds, the RPG still show — childcare content leaking into a clinic.
  Before the other verticals ship, the curriculum surfaces (Action Words,
  This Week, Thinking, the forge, the curriculum Today cards) must gate on
  `vertical == 'childcare'`.

So: the engine *fits* the five verticals now; making them *shippable* is a
picker + a curriculum gate, both bounded.

---

## Axis 2 — the primitives → human-development contexts (universal, re-skinnable)

The eleven atoms don't change from age 5 to 80. What changes is the
*content* — the verbs, the worlds, the questions — which is all bundled
JSON, so it re-skins the same way the curriculum was built this session.
The atoms map cleanly onto any context where humans grow, reflect, and are
seen:

| Context | Subject | Verb becomes | Reveal becomes | Book becomes | Wall becomes |
|---|---|---|---|---|---|
| **Afterschool (today)** | a child | an action word | the world you were | the journal | the room's questions |
| **Corporate L&D / teams** | a teammate | a working behavior | the strength that emerged | the growth log | the team's open questions |
| **Senior / memory care** | an elder | a gentle action | the self that surfaced today | the life-story book | the shared remembering |
| **Family / home** | a kid | a house verb | who they were at dinner | the family scrapbook | the fridge questions |
| **Therapy / SEL clinic** | a client | a coping action | the pattern revealed | the session journal | the group's wall |
| **Camp / scouts** | a camper | a trail verb | the animal they were | the patch book | the campfire questions |

Every row is the *same code* — the same Pick, the same Reveal mechanic, the
same Scale, the same Question-on-the-Wall — with a different bundled
content pack and a different label set. The "act → discover who you are"
reversal works on a 6-year-old and a sales team alike; that's the whole
bet of the primitives.

**What's real / what's conceptual:**
- ✅ The atoms are real code (`PRIMITIVES.md` grounds each).
- ✅ The re-skin *pattern* is proven — every curriculum piece this session
  is bundled JSON swapped behind the same widgets.
- ⚠️ Only the childcare content pack exists. A new context = a new content
  pack (verbs/worlds/questions) + a label set + the same code.

---

## The honest summary

- **The engine fits the five operational verticals now** (re-label + a
  picker + a curriculum gate).
- **The experience fits the human-development contexts** (re-skin the
  bundled content; the atoms and the code don't move).
- The overlap — e.g. **corporate team development** — wants *both*: a new
  label set (Company / Team / Teammate) AND a re-skinned content pack
  (working-behavior verbs instead of CARRY/LISTEN). That's the richest
  target, and it's additive, not a rewrite.

The product isn't "an afterschool app." It's an **engine for being seen +
growing, in any room, at any age** — childcare is the first content pack
and the first vertical, not the ceiling. Everything we built this session
is one pack on a system designed to hold many.

---

*Living doc. New vertical → add its `VerticalLabels` set + (if it's a
development context) a bundled content pack, and gate the childcare
curriculum off it. See [labels.dart](../lib/core/vertical/labels.dart) and
[PRIMITIVES.md](PRIMITIVES.md).*
