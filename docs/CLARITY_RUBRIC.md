# Clarity & Noise rubric — does each screen tell the user what to do, without overwhelm?

A per-screen scoring instrument, separate from `docs/SCREEN_RUBRIC.md` (which
is the structural gate — chrome clearance, the four states, a11y). This one
measures the *felt* experience: **noise** (how much competes for attention)
and **intuitiveness** (does the user immediately know what to do and get what
they came for). Both are derivable from the widget tree, so scores are
comparable across screens and re-runnable.

Two scores per screen, each **0–10**. Plus a one-line "biggest lever."

---

## NOISE — cognitive/visual load (lower is calmer; 0 = serene, 10 = overwhelming)

Add the points. These count what competes for the eye *on first paint, above
the fold*.

**N1 — Competing sections** (distinct top-level visual blocks: header, cards,
lists, banners, strips, action rows):
- 0–2 blocks → 0 · 3–4 → 1 · 5–6 → 2 · 7+ → 3

**N2 — Competing actions** (buttons / CTAs / tappable affordances reading as
primary-or-equal weight; persistent chrome counts):
- 1 → 0 · 2–3 → 1 · 4–6 → 2 · 7+ → 3

**N3 — Text density** (uninterrupted prose / long copy the eye must wade through):
- minimal/scannable → 0 · moderate paragraph(s) → 1 · dense wall → 2

**N4 — Decorative & color variety** (distinct accent colors, icons, gradients,
illustrations competing simultaneously):
- calm/monochrome → 0 · some variety → 1 · busy/many accents → 2

Max 10. Higher = noisier.

---

## INTUITIVENESS — does the user know what to do? (higher is clearer; 0–10)

**I1 — One obvious primary action** (a clear next step):
- absent/ambiguous → 0 · present but not emphasized → 1 · single emphasized CTA → 2

**I2 — Label & copy clarity** (plain, action-oriented, no jargon/engine terms):
- confusing → 0 · ok → 1 · excellent → 2

**I3 — Hierarchy** (the most important thing reads first / largest / on top):
- flat or inverted → 0 · ok → 1 · strong, guides the eye → 2

**I4 — First-run / empty guidance** (a newcomer with no data knows what to do):
- none/blank → 0 · present → 1 · exemplary (icon + one line + CTA) → 2

**I5 — Recognition over recall** (key options visible, not buried behind a
gesture / menu / deep link):
- buried → 0 · mostly visible → 1 · all in view → 2

Max 10. Higher = clearer.

---

## Verdict — the 2D placement

| Noise | Intuitiveness | Verdict | Meaning |
|---|---|---|---|
| ≤3 | ≥7 | ⭐ **Serene & clear** | the goal — calm and obvious |
| 4–5 | ≥7 | ✅ **Clear** | a little busy, still obvious |
| ≥6 | ≥7 | ⚡ **Busy but clear** | powerful/dense; watch it doesn't tip |
| ≤3 | ≤5 | 🌫️ **Sparse / unclear** | calm but the user is lost or under-served |
| ≥6 | ≤6 | 🔴 **Overwhelming** | fix first — loud AND confusing |
| else | | 🟡 **OK** | middling on one axis |

The danger zone is **🔴 high-noise + low-intuitiveness**. The aspiration is the
top-left: **⭐ low-noise + high-intuitiveness**. A screen can be legitimately
busy (⚡) if it stays obvious — a power surface for an expert user — but every
busy screen is one regression away from overwhelming.

---

## How to score

Read the screen's `build()` (and the widgets it composes). Count N1–N4 and
I1–I5 from what actually renders on first paint for the *primary* (data) state.
For the empty state, score I4 from the empty branch. When a screen has multiple
phases (setup → present), score the phase the user lands on first; note the
other if it diverges. Record: `screen · route · NOISE · INTUITIVENESS ·
verdict · biggest lever (one line)`.

The "biggest lever" is the single change that would most improve the score —
the actionable output. Not a list; the one thing.
