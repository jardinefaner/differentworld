# Different World — the brand

The identity contract. [VISION.md](VISION.md) is *why* the app exists;
this is *how it shows up* — in pixels, words, and behavior. Agents and
humans enforce this doc the way they enforce the theme: a screen that
violates it is a defect, not a taste difference.

Settled 2026-07-05 (the Mobbin/brand session). Change it deliberately,
never by drift.

---

## Positioning

**Every childcare app is a ledger. Different World is a book being
written.**

The category leader (Brightwheel) and its clones sell management to
directors: attendance in, incident reports out, a colorful toolbox of
forms. We invert it — the daily two-second capture is the same data
that becomes the child's story, the weekly wrap, the Summer Book, the
year-end keepsake. The keepsake is not a feature; it is the promise
the logging quietly feeds.

- **The foil**: the compliance-ledger aesthetic — dashboard density,
  cool grays, toolbox iconography, exclamation-point copy. When a
  design choice resembles the foil, it's wrong even if it's common.
- **The bet**: calm and beauty are trust signals. A parent decides in
  sixty seconds whether this is "school homework" or "a window into my
  kid's day."

## Personality — the calm host

The app behaves like the best teacher in the building: present, warm,
never performing. Knows what's next. Never panics offline. Hands a kid
the device without fear. Says one short sentence, then gets out of the
way. "The interface should feel like a deep breath, not a dashboard"
(VISION.md).

## Visual system — the five laws

All five are shipped and mechanically enforced; this section names them
so nobody re-litigates them screen by screen.

1. **One left edge.** Flush-left, flat, a single accent edge — never
   boxed cards-within-cards. (The Calm look; `display_style_setting`.)
2. **Clear-glass chrome over edge-to-edge paper.** The pills and the
   omnibox bar have NO fill; the surface runs under them; content
   clears them at init and end. (CLAUDE.md UI north star; EdgeScaffold.)
3. **Warm, never white.** Paper `#F4F1EA` light / warm charcoal
   `#2D2820` dark; teal seed `#2A9D8F`; antique gold `#C79A3E` for the
   book/keepsake moments. No cool M3 grays. (theme.dart, design_tokens.)
4. **Two voices of type.** Fraunces (display serif) speaks to the heart
   — titles, heroes, the book. Space Grotesk does the work — body,
   labels, chrome. Sentence case everywhere; no UPPERCASE shouting, no
   w800+ weights outside the raw stages.
5. **Obvious first.** The best instruction is never read. Content-driven
   world accents stay muted and belong to content, not chrome.
6. **One thing at a time, readable in half a second.** A live-room
   surface is an INSTRUMENT: it owns the screen while it runs, it puts
   what you press at the bottom and what you read at the top, and it
   shows instructions only while they are news. The launcher above it
   reports live state (`2:14 left`) so you never open a thing to learn
   whether it is running. (CLAUDE.md "The half-second rule".)

**Glow is a scarce resource.** At most ONE emphasised action per
screen — a second highlighted thing makes both mean nothing. Depth
comes from layered lightness, never from borders stacked on borders.

## Voice

Host-present, verb-first, zero jargon (the `copy-tone` skill governs
details). The app never says "successfully", "please", or "error:";
it says what happened and what to do. Empty states invite ("No
observations yet."), never apologize. Family-facing copy never leaks
internals — no exception text, no other child's name.

## Reference set (Mobbin study list)

When designing a NEW surface, study execution on mobbin.com — patterns,
not palettes:

- **Calm/warmth**: Headspace, Calm — whitespace + warm palette reading
  as "breathe."
- **Serif-led editorial**: Airbnb, Notion — display serif for emotion,
  workhorse sans for tools (our exact type split).
- **First-minute trust**: consumer onboarding flows — what Lauren sees
  in her first sixty seconds.
- **The foil to check against**: Brightwheel and the b2b childcare
  clones — if a new screen would look at home there, redesign it.

## Enforcement — where the teeth are

- `scripts/check_theme_adherence.sh` + Flutter Theme Guard — no
  hardcoded colors on themed surfaces (docs/THEME_ADHERENCE.md).
- `scripts/check_type_adherence.sh` — law 4, made checkable: no NEW
  uppercase labels or w800+ weights on a themed surface. Added
  2026-09-03, because until then this section claimed all five laws
  were "mechanically enforced" while type had **no checker at all** —
  nothing in the repo grepped for a weight, a `.toUpperCase()`, or a
  font family. 61 themed files had drifted back to the retired
  Jost-era treatment (46 uppercase, 25 w800+) and nothing said so.
  **The backlog was cleared 2026-09-03** — all 61 migrated to sentence
  case and w700. What survives uppercase is deliberate and named: the
  wordmark (a logotype, not UI copy), the certificate facsimile (the
  diploma convention), license plates, join codes and channel topics,
  file-format acronyms, avatar initials, and the Through-My-Eyes
  scripts, whose say-lines are VERBATIM by rule. Those carry a
  per-line `// raw-canvas` marker or are non-display code, so the
  guard stays honest rather than merely quiet. Reach for
  `SectionEyebrow` rather than retyping the label-above-a-title
  treatment.
- `docs/SCREEN_RUBRIC.md` + Screen Rubric agent — chrome clearance,
  four states, primitives, a11y.
- `tool/score_screens.py` → `gallery/screen_scores.md` — the measured
  full-codebase look audit (run after golden regens; never eyeball).
- The `copy-tone` skill — voice.
- The Calm + show-widget-look memories — the in-chat mockups are the
  spec; Fraunces/Space Grotesk/warm paper are non-negotiable.
