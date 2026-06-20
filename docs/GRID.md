# The grid — modular bento layout

One modular column grid, re-packing across devices, so a dashboard reads as
**one system reflowing** rather than three hand-built layouts. This is the
durable spec behind the bento home and (planned) the schedule matrix; the
mockups that drove it are the source of intent, this is the contract.

## The primitive

`lib/shared/widgets/bento_grid.dart` — `BentoGrid` + `BentoSpan` + `BentoTile`.
Reach for it for any **overview / dashboard** surface (a home, a planner
matrix, a gallery). NOT for forms (wrap in `ConstrainedBox(maxWidth: 600)`)
and NOT for a simple list (`ListView.builder`). The grid is for *navigating*,
where every tile is a destination sized by importance.

```dart
BentoGrid(tiles: [
  const BentoTile(
    id: 'now-next',                                  // stable key — see a11y note
    span: BentoSpan(tablet: 4, desktop: 4, rows: 2), // the hero
    child: _NowNextModule(),
  ),
  // …
])
```

## The column grid

`BentoGrid` reads its own width via `LayoutBuilder` and picks the column count:

| Breakpoint | Width | Columns |
|---|---|---|
| Phone | < 600 | **2** |
| Tablet | 600–1100 | **4** |
| Desktop | ≥ 1100 | **6** |

A tile declares how many of those columns it claims **per breakpoint** + how
many row-heights tall it is, via `BentoSpan(phone:, tablet:, desktop:, rows:)`.
Omit any arg that matches the default (`phone 2 / tablet 2 / desktop 2 /
rows 1`). Two shorthands exist: `BentoSpan.wide()` (full row at every width)
and `BentoSpan.hero()` (full on phone, 4-of-6 on desktop, 2 rows tall).

## The size vocabulary (importance = span)

Keep tiles to a small vocabulary so a screen built from them reads as the
system — the same discipline as the component bible's atoms/molecules:

| Shorthand | Desktop span × rows | Use |
|---|---|---|
| **S** | 2 × 1 | a count / a single stat (Captures, Tasks) |
| **M** | 2–3 × 1 | a labelled module (This week, Spotlight) |
| **L** (hero) | 4 × 2 | the one "what matters now" (Now & Next) |
| **Tall** | 2–4 × 2 | a short list (Rooms) |
| **W** | full × 1 | a banner (a live-session strip) |

## Packing rule (Wrap is 1-D, not masonry)

`BentoGrid` flows tiles in a `Wrap`, so it packs left-to-right and down — it is
**not** a true 2-D masonry that back-fills gaps. The consequence: a short tile
placed next to a 2-row tile leaves a gap below it. **Tune spans so each
breakpoint packs into clean runs**: put the tall tiles together, the short
tiles together. The bento home does this — Hero (4×2) + Rooms (2×2) fill the
tall top run at desktop; Captures + Tasks + This-week fill the short run below;
at tablet/phone the same five reflow into full-width tall tiles + a 2-up short
row. (True masonry is the deferred refinement if raggedness at odd widths ever
bites.)

## Laws inherited from the rest of the system

- **a11y / text-scale:** tiles are **min-height, never fixed** — content grows
  past the floor so a 200% text scale never overflows a box. Don't put a
  `Spacer()` in a tile's `Column`: under the min-height (unbounded `maxHeight`)
  it throws a `RenderFlex` overflow. Use a fixed gap; content top-aligns.
- **stable keys:** every tile carries an `id` → `ValueKey('bento-$id')`. Tiles
  that appear/vanish at runtime must key so a neighbour can't inherit a
  vanished tile's Element (the Wrap-children-need-keys rule).
- **theme adherence:** tile colours come from `ColorScheme` roles or a
  content-driven accent run through `AppColors.onAccent(fill)` — never a
  hardcoded `Colors.*` / `Color(0x…)`. See docs/THEME_ADHERENCE.md.
- **chrome clearance:** the bento body uses `SafeArea` so `EdgeScaffold`'s
  published top-chrome band insets it automatically — no per-screen math.

## The global toggle — "Bento everywhere"

Every bento screen is **opt-in + reversible** (the "ship new layouts as
toggles" rule). On top of each screen's own per-screen toggle there's ONE
master switch — `bentoEverywhereProvider`
(`lib/features/settings/bento_everywhere_setting.dart`, Settings → Preferences
→ "Bento everywhere") — that opts the WHOLE app in at once. The user's call:
*because it's reversible, the bento language can spread to every screen safely.*

**Every new bento screen wires through `bentoEnabled`**, never the per-screen
provider alone:

```dart
final bento = bentoEnabled(
  ref,
  perScreen: ref.watch(myScreenBentoProvider).value,
);
return bento ? _bentoBody(...) : _flatBody(...);
```

`bentoEnabled` returns `global || perScreen` — the master switch turns the
screen's bento on AND its own toggle still works for granular control. (The
home slot is routing-gated, so the router ORs the two inline.) This is how
"bento for ALL screens" stays one tap, not N: add a variant, gate it via
`bentoEnabled`, done. Screens that are grid anti-patterns (feeds / forms /
TOC-detail) get the calm CARD treatment under the same switch, not a forced grid.

## Consumers

- **Bento home** — `lib/features/today/today_bento_screen.dart`, opt-in via
  `bentoHomeProvider` OR the global switch. Same Today providers, re-laid
  out. Precedence at the home slot: cockpit > bento > Today scroll.
- **Program hub** — `lib/features/action_words/program_hub_screen.dart`
  (`programHubBentoProvider`). The season as tiles — world hero / today / cast
  / focus / journey + the children as a responsive card grid.
- **Child day** — `lib/features/today/child_day_screen.dart`
  (`childDayBentoProvider`). INTERACTIVE tiles — words + mood keep their live
  tap targets (plain `_DayTile` surfaces, not single-tap `BentoModule`s); the
  gallery stays full-width below.
- **Library card grids** — `CatalogCard` / `CatalogGrid`
  (`lib/shared/widgets/catalog_card.dart`) is the always-on (no toggle) browse
  shape: missions / activities / world book / themed worlds / heroes hub.
- **Per-child world** — `lib/features/child_world/child_world_screen.dart`
  (`/subjects/:id/world`). Each child's own weekly hub — intention / project /
  day / growth as four bento tiles. The first non-home bento surface, and the
  template the candidates below should follow.
  - **Gotcha (cost a render crash):** a bento cell is min-height /
    **unbounded-max** (it grows ragged to fit, never clips), so a tile body
    must SHRINK-WRAP — NO `Expanded` / `Spacer` inside a tile. A flex child
    against an unbounded height throws "RenderFlex children have non-zero flex
    but incoming height constraints are unbounded." Use `mainAxisSize.min` +
    fixed `SizedBox` gaps; the cell's `minHeight` is the tile's floor.
- **Schedule matrix** *(planned)* — cohorts × time on the same grid; the
  wide-screen lens over `schedule_blocks`, degrading to the per-cohort tabs on
  phone (the deferred "Maya tablet-first schedule").
- **Spellbook** *(candidate)* — `lib/features/spellbook/spellbook_screen.dart`
  already gathers today + this week's project + the story; it's the
  program-level sibling of the per-child world hub and the most natural next
  bento (three modular tiles over the same providers).
- **Toolkit** *(candidate)* — `lib/features/toolkit/toolkit_screen.dart` is a
  flat ~10-card grid; bento would weight the tools by importance instead of a
  uniform list.
