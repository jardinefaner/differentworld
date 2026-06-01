# Brain Breaks — the activity roadmap

**Status:** build plan (2026-06-01). Synthesis of four lens passes (activities, role-card decks, content libraries, UI/chrome) against the shipping activity runtime (`activity_script.dart`, `this_or_that_screen.dart`, `content_bank.dart`, `roles.dart`) and the live-block model (`docs/LIVE_BLOCK_CONTEXT.md`). Companion to `docs/ROLES_SMART_PRACTICE.md` (the SEL/practice spine) and `docs/CONTENT_BANK.md` (the content interface).

---

## 1. The through-lines

Four principles tie every change below together. When a decision is ambiguous, these break the tie.

1. **Brain breaks are for TEACHERS — host-paced, no typing, no right/wrong.** The room responds *aloud*; the teacher holds the baton and drives a **Control** view (Back / Reveal / Next) while the room watches a **Presentation** view. No `TextField` as the primary input. No grader, no score, no red "wrong" wall facing a child. `this_or_that_screen.dart` is the reference shape (Presentation + `_ControlBar`/`_ControlPanel`); the three screens that still type + grade are the urgent reshape.

2. **Document everything into the book.** Every activity currently throws its results away — they live in ephemeral screen state (`_answers`, `_shots`, `_history`, `_words`, the live `PatternCanvas`). The rails already exist: a run produces `entries(kind, payload, scheduleBlockId)` tied to the live block (runtime doc §7 + LIVE_BLOCK_CONTEXT.md §5's nullable `schedule_block_id`), and binary media (photos / audio / pattern-PNG) rides the Storage path (CLAUDE.md "Binary media never goes through PowerSync"). Same pipeline for all seven; the artifact auto-flows to the showcase + family timeline.

3. **One floating-glass chrome language — never a solid bar.** The single source of truth is `lib/shared/widgets/glass_panel.dart`: floating glass = **transparent `Material` + `BackdropFilter` blur + low-alpha surface tint + 0.5px outlineVariant border**, wrapped in a `RepaintBoundary`. Anything that paints a solid/near-solid `surface*` color with **no blur** is a violation. Immersive *content* (the colored prompt fields) is allowed to be bold; *chrome* (back / actions / control bars / sheets / reveal banners) must float.

4. **Breathable space.** One primary action per view, full-width, ≥ 64 dp. Outer gutter ≥ 20 dp, section gap ≥ 24 dp. Float chrome over content with a margin so the content shows through and around it — never shelve it flush to the screen edge. Let absence be the signal (collapse to zero height, no "nothing here" filler).

---

## 2. Activity matrix

The deck (`brain_breaks_screen.dart`) launches **8 routes / 7 distinct surfaces**. Two routes point at math: `/activity/math` (Many Paths, `math_runner_screen.dart`) and `/activity/math-game` (`math_game_screen.dart`) — both type + grade today.

| Activity (route, file) | Reshape needed? | How it documents | Presentation form | Different take |
|---|---|---|---|---|
| **Quick Picks · This-or-That** (`/activity/this-or-that`, `this_or_that_screen.dart`) | **No — it's the reference.** Borrow its `_ControlBar`/`_ControlPanel` for the reshapes. | `vote` phase: teacher taps a hands-up tally per side → `entries(kind:'this_or_that', payload:{a,b,votesA,votesB})`. | **Already met the "color the whole screen" ask** — `_Half` paints top color A / bottom color B with `_OrBadge` between. Push: winning color fills more of the screen on reveal (60/40 mirrors the tally). | **"Stand on a side."** Hand the tablet around; each kid taps their half, passes it on; a live bar accrues. A poll that documents itself. |
| **Act It Out · As-If** (`/activity/as-if`, `as_if_screen.dart`) | Minor — kid-paced solo today; add an optional **host mode** (project the line big, teacher taps Next). | **Record the performance** (the richest documenting win): mic → audio `XFile` → Storage → `entries(kind:'as_if', payload:{line,asIf}, attachment=audio)`. A child's voice is the artifact. | Black screen + amber "AS IF" card is good immersive form. Host mode: fill the screen with the emotion's color (terrified = cold blue, won-a-prize = gold). | **"Guess the As-If."** One kid performs; the room guesses which hidden card they drew. Tap-to-reveal — adds a guess loop, zero typing. |
| **Beat the Letter** (`/activity/starts-with`, `letter_words_screen.dart`) | **URGENT — drop the `TextField` + `_check` + `_Verdict` + "Add it".** New shape = This-or-That split: Presentation = giant `_LetterChip` + category; Control = one big **"Someone said it ✓"** counter + chip strip the teacher fills from shout-outs + Next letter/category. Room calls aloud; teacher counts. | `entries(kind:'beat_the_letter', payload:{category, letter, count, words[]})`. The recap becomes the saved card: "Animals with C — the room found 11." | Letter DOMINATES — full-bleed amber, letter at `displayLarge`, category banner. Each tapped word pops in as a projected chip. | **"Beat the clock, together."** A 60s `nonStop` ring drains; the room shouts, teacher taps each. Score = room's count vs last round, never per-kid. |
| **Math Game** (`/activity/math-game`, `math_game_screen.dart`) | **URGENT — most quiz-like of all.** Kill `MathMechanic.type`'s `TextField`, `_q.isCorrect()`, `_score`, ✓/✗. Reshape to host-present: big prompt, teacher taps **Reveal** (not grade), then Next. Choose/true-false buttons stay as *the room votes*, not *answer checked*. **Recommend folding into Many Paths and retiring the duplicate** (see §6). | Once host-present, save the session *shape*, not a score: `entries(kind:'math_game', payload:{questions:[…], blockId})`. No grades stored. | Full-screen, one number/equation at `displaySmall`+. Reveal animates the correct choice glowing — celebratory, not corrective. | Fold its varied mechanics (choose / true-false / sequence) into Many Paths' present→create→reveal→ponder script as the warm-up phase. One math card on the deck. |
| **Many Paths · Math inverse** (`/activity/math`, `math_runner_screen.dart`) | **URGENT — best-architected (rides `ActivityRun` + `mathInverseActivity`), but the `create` phase is one kid typing into one field while the room watches.** Reshape `create`: teacher taps **"Add a path the room found"** → tiny inline entry the *teacher* fills from shout-outs (or a number-pad/operator stepper), each banked as a chip. The live `_VerdictChip` stays as gentle *teacher* feedback, never a red wall facing a kid. Reveal + ponder phases are already perfect — keep verbatim. | `entries(kind:'math_inverse', payload:{target, paths:[…]})` (runtime doc §7's exact projection; doc explicitly defers this today). Reveal becomes the artifact: "12 — the room found 7 roads." | Strong already (giant target, primary color, chip wall). Make the reveal a **wall that fills** — every path tiles the screen ("one destination, many roads"). | **"Build it, don't type it."** Tap-tiles: number pad + operators the teacher (or a passed-around kid) taps to assemble `6+6`; evaluator confirms it hits the target. Works for pre-writers in the 4-6 band. |
| **Photo Studio** (`/activity/photo`, `photography_runner_screen.dart`) | **No — `shoot → present` done right.** Immersive full-screen camera, mission banner, filmstrip, curate gallery, per-photo inline reflection, present phase. | **The real gap.** Wire the shared `_Shot`s through Storage (compress → `student-photos` → `entries(kind:'photo', payload:{prompt, reflection}, attachment=path)`, block-tied). The showcase's first real images come from here. | `_presentation` (shared photos in `CollageGallery`) is already the immersive findings view. | **A prompt series → a tiny photo essay.** Three rotating missions (shadow / something blue / a pattern); the share-picks auto-compose into a 3-shot story saved as one `entry`. |
| **Role Cards** (`/activity/roles`, `role_cards_screen.dart` + `roles.dart`) | Not a typing problem. Gaps: (a) **add theme decks** (§3), (b) it doesn't *do* anything — no pick, no record. Build the "Today I am ___" pick. | Pick a role → `entries(kind:'action_words', payload:{role, habits[3]})` per kid per day. The 3 `artifacts` are literal capture prompts → photo/audio into the book. "Today Maya was a Bee — she gathered, she pointed the way." The strongest SEL/family artifact. | `_RoleCardFace` glass sheet is good for browse. Kid-mode "I am ___ today" goes immersive — full-screen in the role's color, 3 habits as tappable check-circles. | **A cohort role-of-the-day.** Teacher (or a spin) assigns the whole room one role; the day's captures aggregate under it — a single block-tied `entry`. |
| **Make a Pattern** (`/activity/pattern`, `pattern_maker_screen.dart` + `pattern_maker.dart`) | **No — cleanest little surface** (system camera, kaleidoscope `PatternCanvas`, density chips). | **The user's explicit ask — build it.** Render the canvas to PNG (`RepaintBoundary` + `boundary.toImage()` → Storage) → `entries(kind:'pattern', payload:{tilesPerRow, kaleidoscope, prompt}, attachment=path)`. The kaleidoscoped result is the keepsake. Small, well-scoped. | Add "Show it big" — `PatternCanvas` full-bleed, no chrome, a `present` phase over the same render. | **The room's quilt.** Each kid's saved pattern is one cell in a cohort `GridView` — a class-made quilt for the block/term. |

**Cross-cutting:**
- **The reshape trio (urgent):** `math_game_screen.dart`, `math_runner_screen.dart` (`create` phase), `letter_words_screen.dart` all carry a `TextField` + grader/validator. Refactor onto This-or-That's split — Presentation = big prompt, Control = host's Back/Reveal/Next. No new architecture.
- **Documenting priority order** (all the same `entries(kind, payload, scheduleBlockId)` + Storage pipeline): **Photo Studio** (real images, 90% built) → **As-If audio** (a child's voice) → **Pattern PNG** (explicit ask) → **Role Cards "Today I am"** (SEL/family win).
- **Two math cards is clutter** — collapse to one (see §6, Wave 3).

---

## 3. Role-card theme decks

The animals stay, untouched. Add a `RoleDeck` grouping above the flat `roleCatalog`; the 23 shipped cards become the `animals` deck's `cards`. **No `RoleCard`-shape change, no migration, no DB** — `_RoleCardFace`, the printable PDF path, and the `habit_mark` loop all keep working verbatim.

```dart
// roles.dart — NEW above the catalogs. RoleCard is UNCHANGED.
class RoleDeck {
  const RoleDeck({required this.id, required this.emoji, required this.name,
                  required this.tagline, required this.cards});
  final String id;            // 'animals' | 'professions' | 'cosmos' | 'story' | 'play' | 'elements'
  final String emoji, name, tagline;
  final List<RoleCard> cards; // same shape as today
  String get fingerprint => id;
}

const roleDecks = <RoleDeck>[
  RoleDeck(id: 'animals', emoji: '🦊', name: 'Animals & Nature',
           tagline: 'Be an animal for the day', cards: roleCatalog), // existing 23, untouched
  professionsDeck, cosmosDeck, storyDeck, playDeck, elementsDeck,
];
```

**The curated set (6 decks).** Every card uses the **existing `builds` trait vocabulary**, so `archetypeForTrait` (the `IDENTITY_SYSTEM.md` §6 trait→archetype bridge) needs **zero new entries** — a kid roaming across decks still rolls up into one coherent temperament.

| Deck | Emoji | Concept | 10 cards (each `{emoji, name, habits[3], artifacts[3], builds}`) | Why it's a different door |
|---|---|---|---|---|
| **1 · Animals & Nature** | 🦊 | The shipped deck — trait through metaphor. | The existing 23 in `roleCatalog`, untouched. | Metaphor. The baseline. |
| **2 · People & Professions** | 👩‍🚒 | Trait through **purpose** — the job exists to help someone. Most legible for the afterschool band. | Builder, Chef, Doctor, Firefighter, Teacher, Farmer, Scientist, Astronaut, Artist, Bus Driver. (Heavy on Doer ×3 / Connector ×2; courage→Protector+Seeker; patience→Anchor; curiosity→Seeker; optimism→Visionary.) | A kid who finds "be a Spider" abstract gets "be a Doctor — you help people who hurt." Seeds family talk + career curiosity. |
| **3 · Space & Planets** | 🪐 | Cosmic bodies as temperaments — the boldest **immersive** deck (pairs with the full-screen-color ask). | Sun, Moon, Star, Saturn, Comet, Earth, Rocket, Satellite, Galaxy, Telescope. (Spread across 7 of 8 archetypes.) | Built for the immersive pick — Sun washes gold, a stretch Black Hole goes near-black. Lights up kids aged past animals who still want wonder. |
| **4 · Story Characters** | 📖 | Archetypal **story roles** (no IP — Hero/Helper/Mapmaker, not "be Elsa"). | Hero, Explorer, Wise One, Guardian, Helper, Storyteller, Quester, Keeper, Dreamer, Champion. (Deliberately ~one-per-archetype — covers **all 8**.) | The only deck *self-aware about the system*: picking a Hero is choosing a temperament out loud — the literal bridge to `IDENTITY_SYSTEM.md` §8 ("keeps picking Wise One + Explorer → a Sage-Seeker"). Richest for the year-end keepsake. |
| **5 · Games & Play Roles** | 🎲 | The parts that make a game work — most **behaviorally immediate**; adoptable in the next ten minutes. | Team Captain, Referee, Puzzler, Builder (Blocks), Aimer, Entertainer, Strategist, Good Sport, Pacekeeper, Caller. (Weighted Sage ×3 / Connector ×2 — the social-thinking emphasis of group play.) | Zero metaphor-gap — *be the Referee* in the next game, and the 3 habits are immediately checkable. Most likely to fire the `habit_mark` loop organically. |
| **6 · Elements & Forces** | 🔥 | The four elements + forces — most **archetypal/pre-verbal**, reaches the youngest 4-6s; 2nd-most immersive after Space. | Fire, Water, Wind, Stone, Lightning, Rainbow, Frost, Volcano, Sprout, Mountain. (Balanced, 6 of 8.) | "Be Fire" / "be Wind" needs no story or job to parse. Intentional cross-deck echoes (🌱 Sprout ↔ 🌱 Seed, ⛰️ Mountain ↔ 🌳 Oak) make decks *siblings*, not disjoint sets. |

> Full card tables (all 50 new cards with habits/artifacts/builds) live in the role-card lens of the brainstorm; paste as `const RoleCard(...)` literals in the file's existing shape.

**How the deck chooser works** (in `role_cards_screen.dart`, between `ContentHeader` and the grid):

- **Staff mode (compact):** a one-line horizontal scroll of `ChoiceChip(avatar: Text(deck.emoji), label: Text(deck.name))`. Tapping swaps `roleDecks[_deckIndex].cards` into the existing grid, re-tints `_palette` to the deck accent, and updates `ContentHeader.subtitle` to `deck.tagline`. State = one `int _deckIndex` (promote to `StatefulWidget`) — ephemeral, no sync, like which catalog tab you're on.
- **Kid mode (deck-as-box):** when `kidModeProvider` is on, the chooser renders as large deck-cover tiles (deck emoji + name) — "open a box, pick a card." Same `roleDecks` source, two renderers gated on `kidModeProvider` (mirrors the rest of the app's kid/staff chrome split).
- **Per-deck immersive tint:** `_RoleCardFace` takes an optional `accent`; Space + Elements are the standout full-screen-color decks for the "Today I am ___" pick.
- **Default + memory:** default `animals` (zero behavior change on first open). Persist the pick across sessions with one `SharedPreferences` int (`lastRoleDeckIndex`), same pattern as `outdoorModeSettingProvider` — **not** synced.

**DB-backed future is free:** when the content bank goes live, a deck is one `ContentItem(kind:'role_deck')` and the AI-generation path authors whole new themed decks into the *same* `RoleCard` shape — the screen, the pick loop, and the archetype rollup don't change.

**Files:** `lib/features/activity_runtime/roles.dart` (add `RoleDeck` + 5 const decks + `roleDecks`; `roleCatalog` unchanged), `lib/features/activity_runtime/role_cards_screen.dart` (chooser + `_deckIndex` + optional `accent`).

---

## 4. Content libraries — math · science · questions

**The key reframe:** math arithmetic is locally-generable and infinite (`math_game.dart` already does it) — **it never touches `content_items`.** The table is for the *non-computable* content.

| Domain | Local-generable? | Needs AI? |
|---|---|---|
| math (arithmetic) | YES — infinite, free, offline | NO (a computer computes arithmetic) |
| math (word problems) | NO (the framing); number stays locally checkable | YES |
| science Q&A | NO (facts must be authored/verified) | YES |
| questions (open prompts) | curated seed first | YES for scale |

### The `content_items` table (6-place checklist + the `space_id` rule)

```sql
-- supabase/migrations/<ts>_content_items.sql
create table public.content_items (
  id          uuid primary key default gen_random_uuid(),
  space_id    uuid references public.spaces(id),   -- NULL = global/shipped, set = this program's
  kind        text not null,                        -- ContentKind values
  payload     jsonb not null,                       -- the shape the activity reads
  fingerprint text not null,                         -- normalized de-dupe hash
  source      text not null default 'curated',       -- 'local'|'curated'|'ai'|'crowd'
  topic       text,                                  -- math:'add'|'mul'; science:'animals'|'space'; else null
  difficulty  smallint,                              -- 1..3, null = ungraded (ages 4-12 won't fit one band)
  status      text not null default 'approved',      -- 'approved'|'pending' — kid-safety gate
  verified    boolean not null default false,        -- math: answer recomputed OK; science: fact-checked
  created_by  uuid references public.members(id),
  created_at  timestamptz not null default now()
);
alter table public.content_items replica identity full;
create unique index content_items_uniq
  on public.content_items (kind, coalesce(space_id, '00000000-0000-0000-0000-000000000000'::uuid), fingerprint);
create index content_items_serve on public.content_items (kind, status, space_id);
```

Four columns beyond the bare shape, each load-bearing: **`topic`** (answer "give me 10 unseen `multiplication`" without parsing payload), **`difficulty`** (ages 4-12 banding), **`status`** (kid-safety gate — `ai`/`crowd` insert `pending`, only `approved` serves), **`verified`** (correctness — separate from safety: a fact can be verified-true but still `pending` until a human approves; a math problem that fails recompute is dropped entirely).

- **RLS:** SELECT relaxed to `using (status = 'approved')` for now (the ES256 `auth.uid()`-null gotcha makes `current_space_id()` return null; activities are not high-value PII). INSERT/UPDATE `using (true)` per the relaxed-write convention.
- **Sync rule** (`by_space`) — global rows (`space_id is null`) need their own line since `by_space`'s `IN (…)` excludes nulls:
  ```yaml
  - SELECT * FROM content_items WHERE space_id IN (SELECT space_id FROM members WHERE id = auth.user_id())
  - SELECT * FROM content_items WHERE space_id IS NULL AND status = 'approved'
  ```
  Redeploy on the PowerSync dashboard + wipe local storage.

**Slots behind `ContentSource` — activities do NOT change.** Add `DriftContentBank implements ContentSource` next to `LocalContentBank` (reads `db.contentItemsDao.watchByKind(...)`, applies the identical unseen-cursor logic). `ContentKind` additions: `mathProblem` (word problems only), `scienceQa`, `question`, `role` (when roles go DB-backed). `this_or_that_screen.dart`, `letter_words_screen.dart`, `as_if_screen.dart` keep calling `_bank.take(kind, n)` verbatim — only the construction line changes (`LocalContentBank.seeded()` → injected `ContentSource` provider). Seen-tracking: in-session `_served` for v1, persisted via the run's `entries` row — defer a `content_seen` table until repeat-avoidance across sessions bites.

### Generation plan + the cache-by-fingerprint rule

`ensureBank(kind, topic, n)` only calls the Edge Function when `remaining(kind) < threshold`; the function's output is filtered against existing fingerprints before insert (AI is **never re-asked** for what we already hold). Fingerprint normalization mirrors the local seeds: `math_problem` → `'$topic|$answer|${stem.collapsed}'`, `science_qa`/`question` → `text.toLowerCase()` collapsed-whitespace.

The fill workflow fans out per domain because **each has a different correctness gate** (the part the user explicitly called out):

```
ensureBank(kind, topic, n):
  if remaining(kind, topic) >= threshold: return
  raw = EdgeFn.generate(kind, topic, n, exclude: knownFingerprints)   // brokered, no PII
  for item in raw:
    if knownFingerprints.contains(fp(item)): continue
    verified = VERIFY[kind](item)
    status   = (verified && kindIsSafe(item)) ? 'approved' : 'pending'
    insert(content_items, ...verified, status)
```

- **`math_problem` → recompute (the strongest gate, and free).** Edge Function returns `{stem, answer, expr}`; recompute `evaluateExpression(expr)` locally (reuse `expression_eval.dart`, no change) and require `== answer`. **If it doesn't compute, the item is dropped, not banked.** AI never asserts a wrong sum.
- **`science_qa` → fact-check pass + human approve.** (a) a second model call ("true for ages 4-12? yes/no + correction") forwards only `yes`; (b) still inserts `status='pending'` for a director to approve. Conservative on purpose — a wrong fact served to a 7-year-old is the worst failure mode.
- **`question` → kid-safety only.** No correctness (open-ended); safety classifier → `approved` if it passes, else `pending`.

### First sample batch (real payloads, ready to seed)

**`math_problem`** (answers pre-computed; the recompute gate would pass each):
```dart
{'topic':'add',      'stem':'A bus has 4 kids. 3 more get on. How many kids now?',        'answer':7,  'expr':'4 + 3'}
{'topic':'subtract', 'stem':'You have 9 stickers and give 2 away. How many are left?',     'answer':7,  'expr':'9 - 2'}
{'topic':'multiply', 'stem':'There are 3 tables with 4 chairs each. How many chairs?',      'answer':12, 'expr':'3 × 4'}
{'topic':'divide',   'stem':'12 cookies shared by 4 friends. How many does each get?',      'answer':3,  'expr':'12 ÷ 4'}
{'topic':'add',      'stem':'2 red balloons and 5 blue balloons. How many balloons total?', 'answer':7,  'expr':'2 + 5'}
```
**`science_qa`** (curated → `approved` + `verified`):
```dart
{'topic':'animals', 'question':'How many legs does a spider have?',          'answer':'Eight',         'explain':'Spiders are arachnids — always 8 legs.'}
{'topic':'space',   'question':'What is the closest star to Earth?',         'answer':'The Sun',       'explain':'It looks different because it is so close.'}
{'topic':'body',    'question':'What pumps blood through your body?',        'answer':'Your heart',    'explain':'It squeezes like a fist about once a second.'}
{'topic':'weather', 'question':'What do we call frozen rain?',               'answer':'Snow (or hail)','explain':'Tiny ice crystals stick together and fall.'}
{'topic':'plants',  'question':'What do plants need from the Sun to grow?',  'answer':'Light (energy)','explain':'They turn sunlight into food — photosynthesis.'}
```
**`question`** (open, no right answer — the curated seed AI later grows):
```dart
{'text':'If you could invent one new animal, what would it be?'}
{'text':'What is something kind you did this week?'}
{'text':'If our classroom had a flag, what would be on it?'}
{'text':'What would you do with a whole day and no rules?'}
{'text':'What is a question you wish you knew the answer to?'}
```
These ship as a `LocalContentBank.seeded()` extension **today** (`source:'curated'`), proving the kinds before any backend exists.

### Build order (all paths)

1. **Seeds first (today, zero backend).** Add the 3 new `ContentKind`s + the ~15 seed rows to `LocalContentBank.seeded()`; new activities consume via the *unchanged* `ContentSource`. Extend `math_game.dart` to take `MathConfig{topics, min, max}` (pure local, no table).
2. **The table (Slice B).** 6-place synced `content_items` + `ContentItemsDao` + `DriftContentBank`. Swap construction to an injected provider that prefers `DriftContentBank` and **falls back to local seeds when dry/cold** (offline-first: never an empty screen). Curated seeds become the table's first `space_id IS NULL` rows.
3. **AI refill last (Slice C).** `ensureBank` + the brokered Edge Function (`docs/SECRETS.md` — master key never on device, no child identifiers) + the per-domain `VERIFY` map. The only new UI is a tiny director review surface for `status='pending'` rows.

**Files:** `lib/features/activity_runtime/content_bank.dart` (kinds + seeds + `DriftContentBank`), `lib/features/activity_runtime/math_game.dart` (`MathConfig`), `lib/features/activity_runtime/expression_eval.dart` (reused for verify, no change), new `supabase/migrations/<ts>_content_items.sql`, new `lib/core/db/dao/content_items_dao.dart`, + the 6-place sync wiring.

---

## 5. UI + chrome fix list

### Floating-glass violations (file:line — fix these)

1. **`lib/shared/widgets/live_block_strip.dart:82-84` — FAKE glass (highest priority).** Solid `Material(color: scheme.surface.withValues(alpha: 0.92))` with **no `BackdropFilter`** — and the comment literally claims "Same translucent glass surface as the omnibox bar." It sits *directly above* the omnibox bar (the two read as one continuous chrome band); side by side the seam is visible. **Fix:** mirror the bar's inline pattern — `Material(color: Colors.transparent)` → `BackdropFilter(ImageFilter.blur(18,18))` → `Container(color: surface @ 0.55, top BorderSide outlineVariant@0.4)`. Keep the existing divider + `RepaintBoundary` (it pulses an animation).

2. **`lib/features/activity_runtime/this_or_that_screen.dart:297-298` — solid control bar.** The wide-layout host `_ControlBar` is a fully opaque `Material(color: surfaceContainerHighest)` slab pinned under the immersive two-color presentation — the most jarring offender on an immersive screen. **Fix:** transparent Material + `BackdropFilter(blur 18)` + `surface @ 0.55` + 0.5px top border. Folds into the §5 immersive redesign.

3. **`lib/features/activity_runtime/this_or_that_screen.dart:160-161` — solid reveal banner.** The "Why? Turn to a partner…" banner is an opaque `Container(color: Colors.black.withValues(alpha: 0.75))`. **Fix:** `GlassPanel(shape: GlassPanelShape.bar)` or inline blur with a dark tint (`Colors.black @ 0.35` over a blur reads far better against the saturated halves). Give it a stable `ValueKey('tot-reveal')` — it's a conditional `Positioned` child of a `Stack` (rubric D1; currently keyless → IME/rebuild hazard).

**Verified NOT violations (leave alone):** `math_runner_screen.dart` / `math_game_screen.dart` (EdgeScaffold pills + inline buttons on a `ColoredBox` canvas — no solid control band); `as_if_screen.dart`, `letter_words_screen.dart`, `role_cards_screen.dart`, `pattern_maker_screen.dart`, the `_BreakCardTile` in `brain_breaks_screen.dart` (these are **content** — colored prompt cards / role tiles / letter chips, not chrome; immersive canvas is allowed bold color); the `omnibox_overlay.dart` / `omnibox_search_screen.dart` `surfaceContainerHighest` instances (inner rows *inside* the already-glass overlay). `role_cards_screen.dart` already does sheets right via `showGlassSheet`.

### Breathability rules

1. **One primary action per view, full-width, ≥ 64 dp.** `_ControlPanel` (72 dp "Next") is the model; make it the norm. Don't line up 3 equal `FilledButton`s in one `Row` (the wide `_ControlBar` crams Back + Discuss + Next + count into one strip — the dense offender).
2. **Outer gutter ≥ 20 dp; section gap ≥ 24 dp.** Brain-break grid spacing (`brain_breaks_screen.dart` `mainAxisSpacing:12`) → 16.
3. **Float chrome, never shelve it.** Chrome over immersive content uses glass + a margin (control bar inset `EdgeInsets.fromLTRB(16,0,16,16)` as a floating pill, not flush `width: double.infinity`). The single biggest breathability lever for activity screens.
4. **Cap line length on text-forward surfaces** (`ConstrainedBox(maxWidth: 600)`, centered). Immersive single-word slides are exempt (display type).
5. **Let absence be the signal.** `LiveBlockStrip` already collapses to zero when nothing's live — apply everywhere; no "nothing here" filler bars.
6. **≤ 2 type weights + 1 accent per chrome surface.**
7. **Deck declutter:** `GridView.extent(maxCrossAxisExtent: 220, childAspectRatio: 0.9, spacing: 12)` is dense — widen spacing, drop to 2 columns on phone, give each card air. Replace the hand-rolled `_BreakCardTile` (`Material + InkWell`) with the `FeatureCard` primitive.

### This-or-That "the whole screen IS the two colors" redesign

Today it already splits into two color halves (`_Half`) with an `_OrBadge` — the "color the WHOLE screen" ask is **80% there.** What breaks the immersion is chrome sitting on top as solid slabs. The redesign is mostly getting chrome out of the way:

1. **Kill the grey control shelf.** Wide layout does `Column[Expanded(presentation), _ControlBar]` — the bar *steals* vertical space. Change to a `Stack`: presentation fills 100%; controls float as a **glass pill** at `Positioned(bottom: 24, left/right: 24)` over the color. (Also resolves violation #2 by construction.)
2. **Phone layout: presentation fills, controls overlay.** Today presentation is a fixed `SizedBox(height:220)` thumbnail then a control panel below. Flip it: presentation `Expanded`/fills; `_ControlPanel` floats in a `GlassPanel(shape: bar)` pinned to the bottom with a 16 dp margin. The whole phone screen goes blue/red.
3. **Reveal banner → glass** (violation #3), with `ValueKey('tot-reveal')`.
4. **Heighten the split.** Soften the `Color.lerp(color, black, 0.28)` gradient at `_Half` to ~0.12 so each half reads as a bold solid block. Keep the `FittedBox` word + the white `_OrBadge` as the only break.
5. **Save affordance:** a tiny glass "saved ✓" corner chip once the tally write lands — the floating-glass corner is the natural home and won't disturb the color field.

Net: two full-bleed color fields + a single floating glass remote — the same visual language as the omnibox bar, zero solid shelves.

### Recommended new rubric item

Add to `docs/SCREEN_RUBRIC.md` (chrome/viewport section):

> **Chrome is floating glass, never a solid bar.** Any persistent chrome surface — back/actions pills, control bars, reveal banners, strips that butt against the omnibox bar, modal sheets — routes through `GlassPanel` / `GlassPill` / `showGlassSheet`, or the omnibox bar's inline `transparent Material + BackdropFilter + low-alpha tint` pattern. A solid or near-solid `surface*`/`black` fill with **no `BackdropFilter`** on a chrome surface is a defect. Immersive *content* fills (colored prompt fields) are exempt — the rule governs chrome, not content. (Enforced by the `screen-rubric` agent.)

---

## 6. Prioritized build waves

Smallest-highest-leverage first. Each wave is independently shippable with a commit between; the `ContentSource` interface + the `entries(kind, payload, scheduleBlockId)` pipeline mean **activities don't change shape across waves.**

### Wave 1 — Chrome consistency + breathability (smallest, fixes an active frustration)
- Fix the 3 floating-glass violations (`live_block_strip.dart:82`, `this_or_that_screen.dart:297` + `:160`).
- Add `ValueKey('tot-reveal')` to the reveal banner.
- Deck declutter: 2 columns on phone, spacing → 16, `_BreakCardTile` → `FeatureCard`.
- Add the "chrome is floating glass" rubric item to `docs/SCREEN_RUBRIC.md`.
- *Pure UI; no schema, no sync. Run `screen-rubric` + `interaction-guard` (touches `this_or_that_screen.dart` + a strip above the omnibox).*

### Wave 2 — The no-typing reshape trio (the other active frustration)
- **Beat the Letter** (`letter_words_screen.dart`): drop `TextField`/`_check`/`_Verdict`; Presentation = giant letter + category, Control = "Someone said it ✓" counter + chip strip + Next.
- **Math Game** (`math_game_screen.dart`): kill `MathMechanic.type` field, `_q.isCorrect()`, `_score`, ✓/✗; host-present with Reveal + Next; choose/true-false become "room votes."
- **Many Paths `create` phase** (`math_runner_screen.dart`): teacher-fills "Add a path the room found" (inline entry or tap-tiles); `_VerdictChip` stays as gentle teacher feedback, never a red wall. Keep reveal + ponder verbatim.
- All three refactor onto This-or-That's Presentation + Control split. Apply the immersive full-color redesign to This-or-That itself here too.
- *No schema. Run `red-team` (kid-tap edge cases) + `screen-rubric`.*

### Wave 3 — This-or-That immersive + retire the duplicate math card
- Land the full This-or-That redesign (Stack, presentation fills, glass-pill controls, heightened split) if not fully done in Wave 1/2.
- **Collapse the two math routes:** fold Math Game's varied mechanics into Many Paths' present→create→reveal→ponder script as a warm-up phase; retire `/activity/math-game` from the deck (keep the route as a redirect or remove + update omnibox/drawer/`docs/FEATURES.md`).
- *Run `feature-mapper` (route + deck + omnibox change) + `blast-radius` on the math-game route before removing.*

### Wave 4 — Documenting: wire the artifacts into the book (highest user-value)
The `entries(kind, payload, scheduleBlockId)` + Storage pipeline, in priority order:
- **Photo Studio** — shared `_Shot`s → compress → `student-photos` Storage → `entries(kind:'photo', …, attachment=path)`, block-tied. (90% built; the showcase's first real images.)
- **Make a Pattern** — `RepaintBoundary` → `toImage()` PNG → Storage → `entries(kind:'pattern', …, attachment=path)`. (The explicit ask; small.)
- **As-If audio** — mic → audio `XFile` → Storage → `entries(kind:'as_if', …, attachment=audio)`. (A child's voice.)
- **This-or-That / Beat the Letter / Many Paths** — the text-only `entries(kind, payload)` saves (tally / word haul / paths). No Storage.
- Add the "saved ✓" glass affordance to each immersive screen.
- *Binary media MUST ride Storage, never PowerSync (CLAUDE.md). Run `preflight` (sync/lifecycle) + `red-team` (offline upload queue).*

### Wave 5 — Role-card theme decks + the "Today I am" pick + content libraries
- **Role decks:** add `RoleDeck` + 5 const decks to `roles.dart`; the chooser in `role_cards_screen.dart` (staff chips / kid deck-boxes); per-deck immersive tint on `_RoleCardFace`; `SharedPreferences` deck memory. *No migration.*
- **"Today I am ___" pick** → `entries(kind:'action_words', payload:{role, habits[3]})` + the 3 artifacts as capture prompts (reuses Wave 4's Storage path). The strongest SEL/family artifact.
- **Content libraries (the 3 sub-steps from §4):** (5a) seeds today → (5b) `content_items` table + `DriftContentBank` + offline fallback → (5c) AI refill + per-domain `VERIFY` + director approve queue. Ship 5a in this wave; 5b/5c can be their own follow-on wave if scope is tight.
- *5b touches the 6-place checklist + a PowerSync dashboard deploy + local wipe. Run `feature-mapper` (new content surfaces) + `preflight`.*

**Why this sequence:** Waves 1–2 hit the two active frustrations the user named (inconsistent chrome, games that still type + grade) with pure-UI / no-schema changes — fastest feel-wins, lowest risk. Wave 3 cleans the duplicate-math clutter. Wave 4 is the biggest user-value (nothing documents today; the showcase has no real source) but depends on the Storage wiring being deliberate. Wave 5 is additive (decks, then the content backend) and rides everything before it — the role pick reuses Wave 4's capture path, and the content table never changes any activity.

---

**Save as:** `docs/ACTIVITY_ROADMAP.md`.

**Relevant files (all absolute):**
- `/Users/jardinefaner/differentworld/lib/features/activity_runtime/this_or_that_screen.dart` — reference Presentation/Control shape; violations at `:160` (reveal banner) + `:297` (control bar)
- `/Users/jardinefaner/differentworld/lib/features/activity_runtime/math_game_screen.dart` + `math_runner_screen.dart` — the two reshape-trio math screens (`/activity/math-game` + `/activity/math`)
- `/Users/jardinefaner/differentworld/lib/features/activity_runtime/letter_words_screen.dart` — the third reshape (`/activity/starts-with`)
- `/Users/jardinefaner/differentworld/lib/features/activity_runtime/photography_runner_screen.dart`, `pattern_maker_screen.dart`, `as_if_screen.dart` — the documenting wins (Wave 4)
- `/Users/jardinefaner/differentworld/lib/features/activity_runtime/roles.dart` + `role_cards_screen.dart` — theme decks (Wave 5)
- `/Users/jardinefaner/differentworld/lib/features/activity_runtime/brain_breaks_screen.dart` — the deck (declutter + `FeatureCard`)
- `/Users/jardinefaner/differentworld/lib/features/activity_runtime/content_bank.dart` + `math_game.dart` + `expression_eval.dart` — the content libraries
- `/Users/jardinefaner/differentworld/lib/shared/widgets/live_block_strip.dart` — fake-glass violation at `:82`
- `/Users/jardinefaner/differentworld/lib/shared/widgets/glass_panel.dart` — floating-glass source of truth
- `/Users/jardinefaner/differentworld/docs/SCREEN_RUBRIC.md` — add the "chrome is floating glass" item
- `/Users/jardinefaner/differentworld/docs/ROLES_SMART_PRACTICE.md` + `docs/CONTENT_BANK.md` + `docs/LIVE_BLOCK_CONTEXT.md` — companion designs
