# Theme adherence — one theme, enforced

The app has **one** centralized theme. Every normal surface draws its colors
from it, so a single OS dark/light flip (or a future palette change) re-skins
the whole product in lock-step. The dark/light + contrast bugs we keep fixing
all came from code that *bypassed* the theme with a hardcoded color — not from a
missing theme. This doc is the contract that stops that class from recurring,
and it has teeth (a CI check + a review guard).

## The single source of truth

| Layer | Lives in | Use it for |
|---|---|---|
| `ColorScheme` (seeded, light + dark) | `lib/app/theme.dart` (`appColorScheme`, `buildLightTheme`, `buildDarkTheme`) | every surface / text / fill color |
| Semantic extension | `lib/app/design_tokens.dart` → `AppColors` | the world-signature `gold`; add the next recurring semantic color here, not as a literal |
| Outdoor (high-contrast) scheme | `lib/features/settings/outdoor_mode_setting.dart` | the explicit sunlight variant only |

In a widget you read color from `Theme.of(context).colorScheme.<role>`
(`surface`, `onSurface`, `primary`, `surfaceContainerHighest`, `onSurfaceVariant`,
…) or `Theme.of(context).extension<AppColors>()`. **Never** a bare
`Colors.white` / `Colors.black` / `Color(0xFF…)` for a fill or text on a themed
surface — that color can't follow light/dark and is the bug.

## Content-driven colors need a contrast helper, not a theme

Some colors come from **content**, not the theme — the per-world accent
(`#E0C050`, `#ff6b6b`, …) loaded from `assets/curriculum/*.json`. No theme
governs these, so when one becomes a **fill** behind text/icons, the foreground
must be chosen for contrast:

- `AppColors.onAccent(fill)` → black or white by the fill's luminance. Use for a
  chip/badge sitting on a raw accent (the light worlds — yellow, gold, cyan —
  fail with hardcoded white).
- `AppColors.readableOnDark(accent)` → a pale, AA-passing tint of an accent for
  **text/icons on a dark/immersive surface** (the raw accent only reaches ~3:1
  on near-black).

## When hardcoding IS allowed — the raw-canvas allowlist

Four surface *types* legitimately don't follow the screen theme. They're the
allowlist in `scripts/check_theme_adherence.sh`:

1. **Print / PDF** (`*_pdf.dart`, `**/templates/*.dart`, `poster_engine.dart`) —
   paper is always white; a screen theme is meaningless. (Also: never
   `PdfGoogleFonts.*` — see the offline gotcha in CLAUDE.md.)
2. **Projection / immersive stages** (`live_session/**`, `speak/**`, the per-game
   stages `games/games/**` + `game_fullscreen.dart`, `world_present_screen`,
   `world_cast_game`, `conductor`, `beat_presenter`) — a deliberate near-black
   canvas with white text, by brand decision. **Their control regions are NOT
   raw** — `game_scaffold` / `game_runner` / `game_controller` follow the theme.
3. **Camera viewfinders** (`photography_runner_screen`, `guided_capture_screen`,
   `multi_shot_camera`, `vehicle_scan_screen`) — black preview, white controls.
4. **Palette / scheme definitions** (`theme.dart`, `design_tokens.dart`,
   `outdoor_mode_setting.dart`) — where the literals legitimately live.

Two more forms are exempt everywhere because they're theme-neutral by nature:
`Colors.transparent`, and `.withValues(alpha: …)` overlays/scrims (a black scrim
under white text over a photo is legible over any image).

If you add a genuinely-new raw canvas, add its path to the allowlist **in the
same change** — a visible, reviewable line, never a silent bypass.

## The teeth

- **CI / local** — `scripts/check_theme_adherence.sh [BASE_REF]` is diff-scoped:
  it fails only on colors *added* vs the base ref in a non-allowlisted file, so
  grandfathered literals don't block anyone and new bypasses can't land. Runs in
  `.github/workflows/ci.yml`. Run it locally before pushing.
- **Review** — the **Flutter Theme Guard** agent (`~/.claude/agents/flutter-theme-guard.md`)
  runs in the Review Council. It applies the judgment the regex can't: *is this a
  legit new raw canvas (→ allowlist it) or a real bug (→ use the scheme /
  `onAccent`)?*

## Closing the loop

A confirmed theme/contrast bug should leave a durable trace: tighten the
allowlist, add a content color to `onAccent` call sites, or extend this doc.
The bar (CLAUDE.md "closing the loop"): after fixing one, ask *what would have
caught this before I wrote it* — then add exactly that.
