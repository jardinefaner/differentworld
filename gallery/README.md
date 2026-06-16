# The component bible

A living, browsable reference for every reusable widget in the app —
each rendered to a PNG (light **and** dark), organised atomically, so we
can always come back and tweak them with the whole vocabulary in view.

This is the design-system source of truth for **look**. The brand laws it
serves: the Calm layout law ([feedback in CLAUDE.md] — one left edge,
flat, hang the chrome, right-align meta, signals keep their tint) and the
colour law ([docs/THEME_ADHERENCE.md] — one theme, no hardcoded colours on
themed surfaces).

## How to view

```sh
open gallery/                 # Finder grid — eyeball every component at once
```
Each component is two PNGs: `<name>__light.png` and `<name>__dark.png`.

## How to regenerate (after you change a widget)

The PNGs are golden snapshots. They're **environment-sensitive and OFF by
default** (font rasterisation differs per machine), so this is a LOCAL,
on-demand render for viewing — not a CI gate.

```sh
RUN_GOLDENS=1 flutter test --update-goldens test/golden/component_gallery_test.dart
open gallery/                 # review the diff before committing
```

The renderer ([test/golden/component_gallery_test.dart]) loads every
bundled font + `MaterialIcons` so glyphs and icons render for real.

## How to add / change / remove a component (CRUD)

1. **Create** — add a `_plate('<tier>/<name>', (ctx) => …)` in
   [test/golden/component_gallery_test.dart] and a row in the table below.
2. **Read** — `open gallery/<tier>/<name>__light.png`.
3. **Update** — change the widget, re-run the regenerate command, eyeball.
4. **Delete** — drop the `_plate`, the row, and the two PNGs.

The **`component-curator`** agent reconciles this file against
`lib/shared/widgets/`: it flags any widget that isn't catalogued yet, any
row whose PNGs are missing, and any Calm / theme-adherence drift. Run it
after adding or restyling a shared widget (`Agent component-curator`).

## Atomic taxonomy

- **Atoms** — primitive, single-responsibility (a button, an avatar, a dot).
- **Molecules** — composed workhorses a screen reaches for (a card, an
  empty state, a header).
- **Organisms** — layout + chrome (scaffolds, the shell, nav). Rendered in
  a later pass — most need a `ProviderScope` + routing world, so they get a
  seeded harness rather than a bare plate.

---

## Catalogued

### Atoms

| Component | Source | Variants shown | Calm | PNGs |
|---|---|---|---|---|
| Action buttons | [primary_action_button.dart], [secondary_action_button.dart], [destructive_button.dart] + themed Filled/Tonal/Outlined/Text | pill actions, all button kinds, destructive | ✅ | [light](atoms/action_buttons__light.png) · [dark](atoms/action_buttons__dark.png) |
| PersonAvatar | [person_avatar.dart] | initials, 3 radii | ✅ | [light](atoms/person_avatar__light.png) · [dark](atoms/person_avatar__dark.png) |

### Molecules

| Component | Source | Variants shown | Calm | PNGs |
|---|---|---|---|---|
| FeatureCard | [feature_card.dart] | neutral · selected · danger · success | ✅ one-edge | [light](molecules/feature_card__light.png) · [dark](molecules/feature_card__dark.png) |
| SectionCard | [section_card.dart] | featured (aggregator) | ✅ | [light](molecules/section_card__light.png) · [dark](molecules/section_card__dark.png) |
| ContentHeader | [content_header.dart] | title + subtitle | ✅ one-edge | [light](molecules/content_header__light.png) · [dark](molecules/content_header__dark.png) |
| EmptyState | [empty_state.dart] | icon + title + message + CTA | ✅ | [light](molecules/empty_state__light.png) · [dark](molecules/empty_state__dark.png) |
| ErrorState | [error_state.dart] | title + detail + retry | ✅ | [light](molecules/error_state__light.png) · [dark](molecules/error_state__dark.png) |
| ErrorBanner | [error_banner.dart] | message + retry + dismiss | ✅ | [light](molecules/error_banner__light.png) · [dark](molecules/error_banner__dark.png) |
| CapSwitch | [cap_switch.dart] | on · off+disabled | ✅ | [light](molecules/cap_switch__light.png) · [dark](molecules/cap_switch__dark.png) |

---

## Not yet catalogued (the curator tracks these)

`lib/shared/widgets/` is ~50 files / **67 public widget classes**. **9 plates
catalogued; ~30 visual components remain** (the rest are sub-widgets or
non-visual). Animated / blur components need a fixed-pump plate first so
`pumpAndSettle` can't hang on a forever-animation — confirmed by grep:
`async_loading` (LoadingSlot), `glass_panel`, `glass_pill`, `skeleton`,
`app_shell`, `live_block_strip`.

**Atoms** — StatusDot, ProgressDots, ScaleBar, DwWordmark, HorizonMark,
SearchBarPill, FloatingBack, FloatingHamburger, GlassPill ⚠️blur,
Skeleton ⚠️shimmer.

**Molecules** — AccentCardTile, CapabilityLockedTile, CollapsibleSection,
NoAccess, FormBody, SubjectPickerSheet, OverflowActions, LoadingSlot
⚠️shimmer, GlassPanel ⚠️blur.

**Organisms** (seeded harness — need a `ProviderScope` + routing world) —
EdgeScaffold, AppShell ⚠️, MainDrawer, DesktopNavRail, MasterDetailScaffold,
FloatingActions, ResponsivePage, ResponsiveGrid, LiveBlockStrip ⚠️.

**Non-visual / behavioural (no plate)** — ShellMetrics, NavDestinations,
RouteChrome, RouteTitle, ShellBackAction, OrientationLock, HoverTap,
DismissGuard, CenterOrScroll, DebugViewerToggle.

[feedback in CLAUDE.md]: ../CLAUDE.md
[docs/THEME_ADHERENCE.md]: ../docs/THEME_ADHERENCE.md
[test/golden/component_gallery_test.dart]: ../test/golden/component_gallery_test.dart
[primary_action_button.dart]: ../lib/shared/widgets/primary_action_button.dart
[secondary_action_button.dart]: ../lib/shared/widgets/secondary_action_button.dart
[destructive_button.dart]: ../lib/shared/widgets/destructive_button.dart
[person_avatar.dart]: ../lib/shared/widgets/person_avatar.dart
[feature_card.dart]: ../lib/shared/widgets/feature_card.dart
[section_card.dart]: ../lib/shared/widgets/section_card.dart
[content_header.dart]: ../lib/shared/widgets/content_header.dart
[empty_state.dart]: ../lib/shared/widgets/empty_state.dart
[error_state.dart]: ../lib/shared/widgets/error_state.dart
[error_banner.dart]: ../lib/shared/widgets/error_banner.dart
[cap_switch.dart]: ../lib/shared/widgets/cap_switch.dart
