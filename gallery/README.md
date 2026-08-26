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
bundled font + `MaterialIcons` so glyphs and icons render for real. The
game renderer also `precacheImage`s every `Image.asset` after pump, so
the picture-card stages show real deck art (without it they snapshot as
empty white mats — the art decodes async).

## Red-teaming the renders (so you don't eyeball every plate)

After a re-render, run the **`gallery-critic`** agent — it READS the
rendered PNGs (the contact sheets + any plate) and returns a prioritised
punch-list against the Calm brand laws: boxy/heavy layouts, w800/w900
type shouts, white-on-light contrast, broken/sparse states, cohesion
breaks. It's the taste-and-quality eyes on the bible.

```sh
# regenerate, then critique
RUN_GOLDENS=1 flutter test --update-goldens test/golden/*_gallery_test.dart
python3 tool/contact_sheet.py
# then:  Agent gallery-critic
```

Triage its findings — some "broken" reads are golden artifacts (emoji
renders as tofu; assets that fail to precache look blank), not app bugs.

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

## Two layers (per docs/VERTICALS.md)

The bible mirrors the architecture's two layers:

- **The shared widgets** (atoms / molecules / organisms below) — the ENGINE's
  visual vocabulary, domain-agnostic, in `lib/shared/widgets/`. Maintained by
  the `component-curator`.
- **The experience tiers** — the GAMES + WORLDS, the childcare *content* layer
  (`lib/features/games/`, `lib/features/action_words/`). Their atoms render by
  seeding a `GameDefinition` / world content, NOT as a shared widget.
  - **`gallery/games/`** ✅ — now a true bottom-up set (atoms → molecules →
    stages), **one plate per item** so each can be seen + tweaked on its own:
    - **6 atom plates** — `games/atom_hero` (the Fraunces serif prompt),
      `atom_eyebrow`, `atom_option` (default · selected · dimmed · poll-row),
      `atom_counter` (the score), `atom_card_tile` (the deck card),
      `atom_vibe` (the 8 calm `GameAccents`). The shared vocabulary every stage
      composes from — so the deck is cohesive *by construction*, not by 21
      separate restyles. Source: [game_stage.dart].
    - **4 molecule plates** — `games/molecule_vote`, `molecule_poll`,
      `molecule_card_board`, `molecule_tally` (the stage shapes the atoms
      compose into).
    - **`games/vibe_palette`** — every game's accent DNA (surfaced the
      duplicate-teal collisions; now the 8 calm `GameAccents`).
    - **all 15 game stages** + `grid_reveal_stage`, each rendered from its own
      `initialState` over the curated content bank (bank games) or hand-dealt
      real deck art (the card games). Fact-or-Fib / Math / Poll route their
      choices through `GameStage.option`; Rhyme / Letter Words through
      `GameStage.counter`; the full-bleed signals (Cues, This-or-That) keep
      their colour but now speak the lighter brand voice (Fraunces heroes,
      `AppColors.onAccent` contrast, no w800/w900 shouts).
    - **all 15 game stages** + `grid_reveal_stage` (the organism layer), each
      rendered from its own `initialState` over the curated content bank or
      hand-dealt real deck art. The card stages `precacheImage` their art so
      they show real photos, not empty mats.
    - Montage: `gallery/games_contact_sheet.png` (**27 surfaces**).
      Renderer: [test/golden/game_gallery_test.dart].
  - **`gallery/worlds/`** — one plate per atom + molecule:
    - **3 atom plates** — `worlds/atom_verb` (gold serif token), `atom_gold`
      (the world accent), `atom_intention` (the intention tile). Plus the
      `worlds/verbs` reference board (the canonical 12, each with its lens) +
      `worlds/gold_accent` (light/dark swatch).
    - **2 molecule plates** — `worlds/molecule_cue_card` (the full-bleed
      signal) + `worlds/molecule_intention_picker` (choose-3-verbs).
    - Montage: `gallery/worlds_contact_sheet.png` (**7 surfaces**).
      Renderer: [test/golden/world_gallery_test.dart]. Still to add (immersive +
      content-coupled): the reveal overlay, spell cards, the world book, the
      beat presenter, and the rest of the eleven primitives (docs/PRIMITIVES.md).

---

## What this bible does NOT cover — and the promotion queue

The catalogue below tracks `lib/shared/widgets/` (63 files). There are
also **65 widgets inside feature folders** (`lib/features/*/widgets/`),
which are deliberately out of scope: a widget built for one screen has no
business in a design system.

But some of them stopped being feature-local a long time ago. These are
referenced from OTHER features, which makes them shared infrastructure
that happens to live in a feature folder — unplated, unreviewed, and
invisible to the gallery-critic:

| Widget | Feature folder | Used by N other features |
|---|---|---|
| `PersonPhotoNetwork` | photos | **14** |
| `PhotoViewer` | photos | **8** |
| `GroupChipRow` | groups | 2 |
| `AttachmentPhotoThumb` | photos | 2 |
| `PhotoSourceSheet` | photos | 2 |
| `NowNextStrip` | schedule | 2 |

`PersonPhotoNetwork` is the clearest case: every surface that renders a
person's photo goes through it, so it is an atom in everything but
location. Promoting it means moving the file and updating 14 imports —
mechanical, but it should be a deliberate change with its own plate, not
a drive-by.

**The rule going forward:** when a feature widget gains its second
consumer outside its own feature, it is a promotion candidate. When it
gains its third, it is overdue.

## Catalogued — 52 component plates + 160 screen plates (all light + dark)

### Atoms

| Component | Source | Variants shown | Calm | PNGs |
|---|---|---|---|---|
| Action buttons | [primary_action_button.dart], [secondary_action_button.dart], [destructive_button.dart] + themed Filled/Tonal/Outlined/Text | pill actions, all button kinds, destructive | ✅ | [light](atoms/action_buttons__light.png) · [dark](atoms/action_buttons__dark.png) |
| PersonAvatar | [person_avatar.dart] | initials, 3 radii | ✅ | [light](atoms/person_avatar__light.png) · [dark](atoms/person_avatar__dark.png) |
| GeneratedPortrait | [generated_portrait.dart] | 8 seeds at list size · 3 at reveal size | ✅ content-driven | [light](atoms/generated_portrait__light.png) · [dark](atoms/generated_portrait__dark.png) |
| StatusDot | [status_dot.dart] | calm · progress · needsAttention · neutral | ✅ | [light](atoms/status_dot__light.png) · [dark](atoms/status_dot__dark.png) |
| ProgressDots | [progress_dots.dart] | step indicators (0 of N, current position) | ✅ | [light](atoms/progress_dots__light.png) · [dark](atoms/progress_dots__dark.png) |
| DwWordmark | [dw_wordmark.dart] | logotype + tagline | ✅ | [light](atoms/dw_wordmark__light.png) · [dark](atoms/dw_wordmark__dark.png) |
| ScaleBar | [scale_bar.dart] | range scales with label + trailing | ✅ | [light](atoms/scale_bar__light.png) · [dark](atoms/scale_bar__dark.png) |
| GlassPill | [glass_pill.dart] | frosted chrome pill (blur captures over content) | ✅ | [light](atoms/glass_pill__light.png) · [dark](atoms/glass_pill__dark.png) |
| HorizonMark | [horizon_mark.dart] | brand mark (teal field, gold sun, white horizon) | ✅ | [light](atoms/horizon_mark__light.png) · [dark](atoms/horizon_mark__dark.png) |
| SearchBarPill | [search_bar_pill.dart] | search input in glass pill (leading icon, trailing close button) | ✅ | [light](atoms/search_bar_pill__light.png) · [dark](atoms/search_bar_pill__dark.png) |
| FloatingChrome | [floating_back.dart], [floating_hamburger.dart] | back arrow pill · hamburger pill (frosted chrome navigation) | ✅ | [light](atoms/floating_chrome__light.png) · [dark](atoms/floating_chrome__dark.png) |
| NavCountBadge | [nav_destinations.dart] | count badge overlay (nav decoration) | ✅ | [light](atoms/nav_count_badge__light.png) · [dark](atoms/nav_count_badge__dark.png) |
| InlineEditableText | [inline_editable_text.dart] | text field converting from label (edit-in-place) | ✅ | [light](atoms/inline_editable_text__light.png) · [dark](atoms/inline_editable_text__dark.png) |
| Skeletons | [skeleton.dart] | SkeletonBox · SkeletonLine · SkeletonListTile · SkeletonShimmer · SkeletonList · SkeletonCards (loading placeholders + full-screen convenience variants) | ✅ | [light](atoms/skeletons__light.png) · [dark](atoms/skeletons__dark.png) |

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
| AccentCardTile | [accent_card_tile.dart] | activity-palettes (teal, pink, amber) | ✅ | [light](molecules/accent_card_tile__light.png) · [dark](molecules/accent_card_tile__dark.png) |
| AccentEdgeRow | [accent_edge_row.dart] | neutral rule · accented state · trailing · tappable | ✅ one-edge | [light](molecules/accent_edge_row__light.png) · [dark](molecules/accent_edge_row__dark.png) |
| PersonFaceWrap | [person_face_wrap.dart] | 7 faces with names · overflow "+N" chip | ✅ | [light](molecules/person_face_wrap__light.png) · [dark](molecules/person_face_wrap__dark.png) |
| InlineAdd | [inline_add.dart] | collapsed "+" · open field (add without leaving the page) | ✅ | [light](molecules/inline_add__light.png) · [dark](molecules/inline_add__dark.png) |
| AccentEdgeCard | [accent_edge_card.dart] | eyebrow + icon, two accents | ✅ one-edge | [light](molecules/accent_edge_card__light.png) · [dark](molecules/accent_edge_card__dark.png) |
| DestructiveButton | [destructive_button.dart] | enabled · disabled | ✅ | [light](molecules/destructive_button__light.png) · [dark](molecules/destructive_button__dark.png) |
| Save controls | [form_save_button.dart] | ready · blocked-by-empty-field | ✅ | [light](molecules/save_controls__light.png) · [dark](molecules/save_controls__dark.png) |
| StickySaveBar | [sticky_save_bar.dart] | over a scrolling form (needs a Stack) | ✅ | [light](molecules/sticky_save_bar__light.png) · [dark](molecules/sticky_save_bar__dark.png) |
| CatalogCard | [catalog_card.dart] | in CatalogGrid, with + without chips | ✅ | [light](molecules/catalog_card__light.png) · [dark](molecules/catalog_card__dark.png) |
| ThumbBar | [thumb_bar.dart] | fixed control clearing the LIVE strip | ✅ | [light](molecules/thumb_bar__light.png) · [dark](molecules/thumb_bar__dark.png) |
| CapabilityLockedTile | [capability_locked_tile.dart] | locked card overlay | ✅ | [light](molecules/capability_locked_tile__light.png) · [dark](molecules/capability_locked_tile__dark.png) |
| CollapsibleSection | [collapsible_section.dart] | collapsed · expanded states | ✅ one-edge | [light](molecules/collapsible_section__light.png) · [dark](molecules/collapsible_section__dark.png) |
| NoAccess | [no_access.dart] | access denied state | ✅ | [light](molecules/no_access__light.png) · [dark](molecules/no_access__dark.png) |
| LoadingSlot | [async_loading.dart] | list shimmer, card stack, spinner variants | ✅ | [light](molecules/loading_slot__light.png) · [dark](molecules/loading_slot__dark.png) |
| GlassPanel | [glass_panel.dart] | frosted sheet surface (the floating-glass chrome) | ✅ | [light](molecules/glass_panel__light.png) · [dark](molecules/glass_panel__dark.png) |
| GlassDragHandle | [glass_panel.dart] | bottom-sheet grab-pill (self-suppresses in dialog / side panel) | ✅ | [light](molecules/glass_drag_handle__light.png) · [dark](molecules/glass_drag_handle__dark.png) |
| FormBody | [form_body.dart] | form container with insets (padding, keyboard room) | ✅ | [light](molecules/form_body__light.png) · [dark](molecules/form_body__dark.png) |
| OverflowActions | [overflow_actions.dart] | action buttons overflow menu (EdgeAction items) | ✅ | [light](molecules/overflow_actions__light.png) · [dark](molecules/overflow_actions__dark.png) |

### Organisms

The standalone four render bare; the other six go through a **seeded
harness** (`_scenePlate` — a director `Viewer` over an in-memory DB with
the Drift watch-streams overridden, plus a real GoRouter for AppShell) so
the full-screen chrome renders for real, both themes.

| Component | Source | Variants shown | Calm | PNGs |
|---|---|---|---|---|
| FloatingActions | [floating_actions.dart] | glass action pill (frosted, over content) | ✅ | [light](organisms/floating_actions__light.png) · [dark](organisms/floating_actions__dark.png) |
| ResponsivePage | [responsive_page.dart] | width-clamped scroll page | ✅ | [light](organisms/responsive_page__light.png) · [dark](organisms/responsive_page__dark.png) |
| ResponsiveGrid | [responsive_grid.dart] | adaptive columns (desktop width) | ✅ | [light](organisms/responsive_grid__light.png) · [dark](organisms/responsive_grid__dark.png) |
| SliverResponsiveGrid | [responsive_grid.dart] | sliver flavor inside a CustomScrollView | ✅ | [light](organisms/sliver_responsive_grid__light.png) · [dark](organisms/sliver_responsive_grid__dark.png) |
| BentoGrid | [bento_grid.dart] | modular dashboard tiles, 2/4/6-col by width (docs/GRID.md) | ✅ | [light](organisms/bento_grid__light.png) · [dark](organisms/bento_grid__dark.png) |
| MasterDetailScaffold | [master_detail_scaffold.dart] | two-pane at ≥1200dp (list + detail) | ✅ | [light](organisms/master_detail_scaffold__light.png) · [dark](organisms/master_detail_scaffold__dark.png) |
| EdgeScaffold | [edge_scaffold.dart] | one screen's scaffold + its floating chrome pills | ✅ | [light](organisms/edge_scaffold__light.png) · [dark](organisms/edge_scaffold__dark.png) |
| AppShell | [app_shell.dart] | the persistent frame — chrome + live strip + omnibox bar (seeded router) | ✅ | [light](organisms/app_shell__light.png) · [dark](organisms/app_shell__dark.png) |
| MainDrawer | [main_drawer.dart] | hamburger drawer — profile + nav spine + groups | ✅ | [light](organisms/main_drawer__light.png) · [dark](organisms/main_drawer__dark.png) |
| MainDrawer · start simple | [main_drawer.dart], [starting_simple_setting.dart] | the same drawer under the first-week trim — 3 destinations + search + Settings | ✅ | [light](organisms/main_drawer_simple__light.png) · [dark](organisms/main_drawer_simple__dark.png) |
| GuardianDrawer | [guardian_drawer.dart] | the family-side hamburger — Today + each child + Messages + Display | ✅ | [light](organisms/guardian_drawer__light.png) · [dark](organisms/guardian_drawer__dark.png) |
| DesktopNavRail | [desktop_nav_rail.dart] | persistent 240dp left nav column | ✅ | [light](organisms/desktop_nav_rail__light.png) · [dark](organisms/desktop_nav_rail__dark.png) |
| LiveBlockStrip | [live_block_strip.dart] | "LIVE · {block}" strip, breathing dot (fixed-pump) | ✅ | [light](organisms/live_block_strip__light.png) · [dark](organisms/live_block_strip__dark.png) |

### Surfaces

The composed presentations a user actually interacts with — not single
widgets but the chrome the app assembles from them, over a dimmed scrim.
The three responsive forms `showGlassSheet` produces share ONE form body;
the `GlassDragHandle` shows in the bottom sheet and self-suppresses in the
dialog / side panel (proof the `GlassSheetScope` mechanism works).

| Surface | Source | Variants shown | Calm | PNGs |
|---|---|---|---|---|
| Bottom sheet | [glass_panel.dart] · `showGlassSheet` < 840dp | glass sheet + drag handle + form | ✅ | [light](surfaces/bottom_sheet__light.png) · [dark](surfaces/bottom_sheet__dark.png) |
| Dialog | [glass_panel.dart] · `showGlassSheet` 840–1200dp | centered glass dialog (handle self-suppresses) | ✅ | [light](surfaces/dialog__light.png) · [dark](surfaces/dialog__dark.png) |
| Side panel | [glass_panel.dart] · `showGlassSheet` ≥ 1200dp | right-docked third column + close strip | ✅ | [light](surfaces/side_panel__light.png) · [dark](surfaces/side_panel__dark.png) |
| Confirm destructive | [destructive_button.dart] | error-tinted delete confirm | ✅ | [light](surfaces/confirm_destructive__light.png) · [dark](surfaces/confirm_destructive__dark.png) |
| Snackbar | M3 inverse-surface | success + error toast with action | ✅ | [light](surfaces/snackbar__light.png) · [dark](surfaces/snackbar__dark.png) |
| Omnibox composer | [bottom_omnibox_bar.dart] | search · capture · slash modes | ✅ | [light](surfaces/omnibox_bar__light.png) · [dark](surfaces/omnibox_bar__dark.png) |
| Omnibox overlay | [glass_panel.dart] · `GlassPanelShape.overlay` | full-bleed suggestion panel (recent + suggested) | ✅ | [light](surfaces/omnibox_overlay__light.png) · [dark](surfaces/omnibox_overlay__dark.png) |

### Screens

Beyond the component bible, **every reachable screen** is rendered too —
inside the real `AppShell` (chrome + omnibox bar) so each plate looks like
the running app, light + dark, in `gallery/screens/`. Montage:
`gallery/screens_contact_sheet.png`.

- **79 of the app's 142 screens catalogued** — the param-free
  destinations (Today, Schedule, Captures, Tasks, Insights, Settings,
  Vehicles, Observations, Family, Missions, Cockpit, Surveys, Toolkit,
  Staff, Supplies, Reviews, …). Each renders its real empty / default
  state — a legitimate gallery render.
- Renderer: [screens_gallery_test.dart](../test/golden/screens_gallery_test.dart).
  A director `Viewer` over an empty in-memory DB seeds every screen; the
  Drift watch-stream timer is drained on unmount. Six screens with an
  ongoing timer (clock / realtime poll / autosave / animation) keep their
  committed plate but skip the local golden test (`_leakyTimer`).
- **Remaining: the 62 param / detail screens** (SubjectDetail,
  GroupDetail, VehicleDetail, MemberDetail, MessageThread, survey pages,
  kid screens, the poster-layout views) — each needs a seeded entity + a
  route param, which is the next wave. Five of those (the card games) are
  already shown in the games tier.

---

## Not yet catalogued

`lib/shared/widgets/` is **65 files**; **52 component plates** catalogued.

Counts drift, so verify rather than trust them:

```sh
ls lib/shared/widgets/*.dart | wc -l                       # source files
ls gallery/{atoms,molecules,organisms}/*__light.png | wc -l  # plates
ls gallery/screens/*__light.png | wc -l                      # screen plates
```

An earlier version of this section claimed atoms, molecules and organisms
were ALL catalogued. That was not true — a 2026-08-24 audit found six
visual widgets with no plate at all (AccentEdgeCard, DestructiveButton,
FormSaveButton, StickySaveBar, CatalogCard, and the then-new ThumbBar).
They are catalogued now, and the claim is not being restated: this list is
what remains.

**Still unplated, and why**

| Widget | Why not |
|---|---|
| `CameraChrome` | needs a live camera; nothing to rasterise |
| `DrawingPad` | needs real gestures — an empty canvas plate says nothing |
| `CapPickerSheet`, `SubjectPickerSheet` | modal sheets needing a seeded route + data; plate as a scene when one is written |
| `BentoModule`, `DayToolsBento`, `SlideBlock` | composed surfaces with heavy data needs; covered indirectly by the screen plates that use them |

**Non-visual / behavioural (no plate, do not catalogue)** — CenterOrScroll,
DebugViewerToggle, DismissGuard, HoverTap, OrientationLock, RouteTitle,
GlassSheetScope, ShellMetrics, RouteChrome, NavDestinations.

The `_platePumped` / `_scenePlate` helpers (fixed-frame pump) cover forever-
animations (shimmer / spinner / the live-strip's breathing dot);
**`BackdropFilter` blur DOES capture in goldens** (glass frost renders
properly). Two things a plate cannot do, learned the hard way: a widget that
is a `Positioned` asserts outside a `Stack` (give it one — see
StickySaveBar), and an indefinite `CircularProgressIndicator` never settles
under `pumpAndSettle` (leave that state to widget tests — see FormSaveButton
`saving: true`).

[feedback in CLAUDE.md]: ../CLAUDE.md
[docs/THEME_ADHERENCE.md]: ../docs/THEME_ADHERENCE.md
[accent_edge_row.dart]: ../lib/shared/widgets/accent_edge_row.dart
[generated_portrait.dart]: ../lib/shared/widgets/generated_portrait.dart
[person_face_wrap.dart]: ../lib/shared/widgets/person_face_wrap.dart
[inline_add.dart]: ../lib/shared/widgets/inline_add.dart
[accent_edge_card.dart]: ../lib/shared/widgets/accent_edge_card.dart
[destructive_button.dart]: ../lib/shared/widgets/destructive_button.dart
[form_save_button.dart]: ../lib/shared/widgets/form_save_button.dart
[sticky_save_bar.dart]: ../lib/shared/widgets/sticky_save_bar.dart
[catalog_card.dart]: ../lib/shared/widgets/catalog_card.dart
[thumb_bar.dart]: ../lib/shared/widgets/thumb_bar.dart
[test/golden/component_gallery_test.dart]: ../test/golden/component_gallery_test.dart
[test/golden/game_gallery_test.dart]: ../test/golden/game_gallery_test.dart
[game_stage.dart]: ../lib/features/games/game_stage.dart
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
[status_dot.dart]: ../lib/shared/widgets/status_dot.dart
[progress_dots.dart]: ../lib/shared/widgets/progress_dots.dart
[dw_wordmark.dart]: ../lib/shared/widgets/dw_wordmark.dart
[scale_bar.dart]: ../lib/shared/widgets/scale_bar.dart
[floating_actions.dart]: ../lib/shared/widgets/floating_actions.dart
[responsive_page.dart]: ../lib/shared/widgets/responsive_page.dart
[responsive_grid.dart]: ../lib/shared/widgets/responsive_grid.dart
[master_detail_scaffold.dart]: ../lib/shared/widgets/master_detail_scaffold.dart
[app_shell.dart]: ../lib/shared/widgets/app_shell.dart
[edge_scaffold.dart]: ../lib/shared/widgets/edge_scaffold.dart
[bento_grid.dart]: ../lib/shared/widgets/bento_grid.dart
[main_drawer.dart]: ../lib/shared/widgets/main_drawer.dart
[starting_simple_setting.dart]: ../lib/features/settings/starting_simple_setting.dart
[guardian_drawer.dart]: ../lib/features/family/guardian_drawer.dart
[desktop_nav_rail.dart]: ../lib/shared/widgets/desktop_nav_rail.dart
[live_block_strip.dart]: ../lib/shared/widgets/live_block_strip.dart
[bottom_omnibox_bar.dart]: ../lib/features/omnibox/bottom_omnibox_bar.dart
[accent_card_tile.dart]: ../lib/shared/widgets/accent_card_tile.dart
[capability_locked_tile.dart]: ../lib/shared/widgets/capability_locked_tile.dart
[collapsible_section.dart]: ../lib/shared/widgets/collapsible_section.dart
[no_access.dart]: ../lib/shared/widgets/no_access.dart
[glass_pill.dart]: ../lib/shared/widgets/glass_pill.dart
[glass_panel.dart]: ../lib/shared/widgets/glass_panel.dart
[async_loading.dart]: ../lib/shared/widgets/async_loading.dart
[horizon_mark.dart]: ../lib/shared/widgets/horizon_mark.dart
[search_bar_pill.dart]: ../lib/shared/widgets/search_bar_pill.dart
[floating_back.dart]: ../lib/shared/widgets/floating_back.dart
[floating_hamburger.dart]: ../lib/shared/widgets/floating_hamburger.dart
[nav_destinations.dart]: ../lib/shared/widgets/nav_destinations.dart
[inline_editable_text.dart]: ../lib/shared/widgets/inline_editable_text.dart
[skeleton.dart]: ../lib/shared/widgets/skeleton.dart
[form_body.dart]: ../lib/shared/widgets/form_body.dart
[overflow_actions.dart]: ../lib/shared/widgets/overflow_actions.dart
