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

## Consumers

- **Bento home** — `lib/features/today/today_bento_screen.dart`, opt-in via
  `bentoHomeProvider` (Settings → Preferences). Same Today providers, re-laid
  out. Precedence at the home slot: cockpit > bento > Today scroll.
- **Schedule matrix** *(planned)* — cohorts × time on the same grid; the
  wide-screen lens over `schedule_blocks`, degrading to the per-cohort tabs on
  phone (the deferred "Maya tablet-first schedule").
