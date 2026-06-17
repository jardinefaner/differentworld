/// Design tokens for Different World — the single home for the values
/// that used to live as scattered literals across feature files.
///
/// Three kinds of token live here:
///   * [AppColors]  — a `ThemeExtension` for semantic colours that the
///     Material [ColorScheme] doesn't model (the world-signature gold).
///     Read via `Theme.of(context).extension<AppColors>()!.gold`.
///   * [AppType]    — the typographic ramp, built from the two fonts the
///     app already bundles (Fraunces + Space Grotesk). No runtime fetch.
///   * [Insets] / [Radii] — the spacing + corner scale, so `14` and `24`
///     stop being magic numbers repeated in every widget.
///
/// `theme.dart` assembles these into the light / dark / outdoor themes;
/// feature code should reach for the named token, never a raw literal.
library;

import 'package:flutter/material.dart';

/// Semantic colours that aren't part of the Material [ColorScheme].
///
/// Today this is just the **gold** world-accent — the signature colour of
/// the Action Words / Different World surfaces (the reveal badge, spell
/// cards, world book). It was a `Color(0xFFE6C079)` literal copy-pasted
/// across seven sites in six files, each re-deciding the light/dark value
/// by hand. Centralising it here means:
///   * one source of truth, tuned per brightness in one place, and
///   * it actually adapts to dark mode (a raw `Color(0x..)` literal does
///     not — that was a latent dark-theme bug everywhere it appeared).
///
/// Designed to grow: the next recurring semantic colour (a "draft/pending"
/// amber, a "live session" pulse) becomes a field here, not a new literal.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({required this.gold, required this.growth});

  /// The world-signature accent. Legible on its own brightness:
  /// a soft pale gold on dark surfaces, a deeper antique gold on light.
  final Color gold;

  /// The "positive / can-do / correct" green. Tuned per brightness so it
  /// passes AA as TEXT on BOTH themes — the recurring `Color(0xFF51CF66)`
  /// literal that was copy-pasted across staff-ladder / runbook / verb-jobs /
  /// scale-bar / math-runner only reads on dark (≈2:1 on a light surface).
  final Color growth;

  /// Light-theme values — deeper tones so they read on the warm-white surface.
  static const light = AppColors(
    gold: Color(0xFF9A7B2E),
    growth: Color(0xFF2E7D32),
  );

  /// Dark-theme values — paler tones so they read on the near-black surface.
  static const dark = AppColors(
    gold: Color(0xFFE6C079),
    growth: Color(0xFF7BD491),
  );

  @override
  AppColors copyWith({Color? gold, Color? growth}) =>
      AppColors(gold: gold ?? this.gold, growth: growth ?? this.growth);

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      gold: Color.lerp(gold, other.gold, t) ?? gold,
      growth: Color.lerp(growth, other.growth, t) ?? growth,
    );
  }

  /// The brightness-correct [gold] for [theme], with a fallback for contexts
  /// that override the theme without re-registering this extension (forced
  /// dark overlays). Reads the SAME token instances — no hex copy that drifts.
  static Color goldOf(ThemeData theme) =>
      theme.extension<AppColors>()?.gold ??
      (theme.brightness == Brightness.dark ? dark.gold : light.gold);

  /// The brightness-correct [growth] for [theme] (same fallback contract as
  /// [goldOf]). Use instead of a hardcoded green for can-do / correct / up
  /// labels so they pass AA on light AND follow dark/light.
  static Color growthOf(ThemeData theme) =>
      theme.extension<AppColors>()?.growth ??
      (theme.brightness == Brightness.dark ? dark.growth : light.growth);

  /// A light, AA-passing tint of [accent] for use as TEXT or an icon on a
  /// DARK surface. The bright categorical accents (teal, blue, …) only reach
  /// ~3:1 on near-black — below WCAG AA. Blending the accent lightly over
  /// white yields a pale accent-tinted near-white that keeps the colour cue
  /// while clearing 4.5:1. Use for captions/labels on the immersive (black)
  /// surfaces; the raw accent stays fine for fills, borders, and large glyphs.
  static Color readableOnDark(Color accent) =>
      Color.alphaBlend(accent.withValues(alpha: 0.30), Colors.white);

  /// Near-black or white TEXT/icon — whichever is legible ON a solid [fill].
  /// A hardcoded `Colors.white` on a LIGHT accent (the yellow, amber, blue,
  /// teal world/activity colours) only reaches ≈2–3:1 — below WCAG AA. This
  /// returns the higher-contrast of the two foregrounds.
  ///
  /// It compares the WCAG contrast ratio of each against [fill] directly
  /// (via `computeLuminance`) rather than a single luminance threshold —
  /// `estimateBrightnessForColor` crosses over at 0.15 and mis-picks the
  /// mid-tones (e.g. deepPurple: black ≈4.2:1 when white is ≈5:1). Picking
  /// the better of the two crosses over at the WCAG midpoint (~0.179), so the
  /// winner clears AA for ANY fill. Used wherever a chip/card/badge sits on a
  /// content-accent fill (see `AccentCardTile`, docs/THEME_ADHERENCE.md).
  static Color onAccent(Color fill) {
    final l = fill.computeLuminance();
    final contrastOnWhite = 1.05 / (l + 0.05);
    final contrastOnBlack = (l + 0.05) / 0.05;
    return contrastOnBlack >= contrastOnWhite ? Colors.black87 : Colors.white;
  }
}

/// The typeface + the full Material text ramp built from it.
///
/// The whole ramp is **Jost** — a geometric / Futura-style sans bundled in
/// `assets/fonts/` (NOT runtime-fetched; that would break offline-first, see
/// the `PdfGoogleFonts` gotcha in CLAUDE.md). One family, like the reference:
/// the hierarchy comes from **weight + case + tracking**, not from mixing
/// fonts. The brand voice is *thin, wide-tracked, uppercase* — so the top of
/// the ramp is light (w300) and loosely tracked, meant to be UPPERCASED at the
/// hero call sites (login wordmark, page titles, empty-state titles, the small
/// "eyebrow" labels). Body stays sentence-case at a normal weight for
/// readability + screen-reader sanity — the vibe lives in the hero moments.
///
/// (Casing can't live in a [TextStyle], so uppercasing happens at the call
/// site — see [AppType.tracking] for the extra letter-spacing a hero/eyebrow
/// should stack on top when it goes all-caps.)
abstract final class AppType {
  /// The display / hero voice — thin, geometric, made to be tracked + capped.
  /// Same family as [ui]; the difference is weight, case, and spacing.
  static const display = 'Jost';

  /// The functional voice (title / body / label). Same Jost family — set as
  /// the global default so any unstyled `Text` speaks it too.
  static const ui = 'Jost';

  /// Extra letter-spacing to STACK on a display/eyebrow style when it's
  /// uppercased at the call site — tracked caps need more air than the
  /// mixed-case ramp bakes in. e.g. `style.copyWith(letterSpacing:
  /// AppType.tracking)` on a `Text('TODAY')`.
  static const double tracking = 3;

  /// The Material 3 ramp, re-voiced for the thin-geometric vibe. Sizes track
  /// the M3 scale; the top is light (w300) + airy; everything is positively
  /// tracked. Colours are omitted so each style inherits the scheme's
  /// on-surface colour per brightness.
  static TextTheme textTheme() => const TextTheme(
        displayLarge: TextStyle(
          fontFamily: display,
          fontSize: 57,
          fontWeight: FontWeight.w300,
          height: 1.08,
          letterSpacing: 1,
        ),
        displayMedium: TextStyle(
          fontFamily: display,
          fontSize: 45,
          fontWeight: FontWeight.w300,
          height: 1.12,
          letterSpacing: 1,
        ),
        displaySmall: TextStyle(
          fontFamily: display,
          fontSize: 36,
          fontWeight: FontWeight.w300,
          height: 1.18,
          letterSpacing: 1,
        ),
        headlineLarge: TextStyle(
          fontFamily: display,
          fontSize: 32,
          fontWeight: FontWeight.w300,
          height: 1.22,
          letterSpacing: 0.8,
        ),
        headlineMedium: TextStyle(
          fontFamily: display,
          fontSize: 28,
          fontWeight: FontWeight.w400,
          height: 1.26,
          letterSpacing: 0.6,
        ),
        // Page titles (ContentHeader) + wide empty-state titles land here —
        // the most-seen "big" style. w400 so it stays crisp when uppercased.
        headlineSmall: TextStyle(
          fontFamily: display,
          fontSize: 24,
          fontWeight: FontWeight.w400,
          height: 1.3,
          letterSpacing: 0.5,
        ),
        titleLarge: TextStyle(
          fontFamily: ui,
          fontSize: 22,
          fontWeight: FontWeight.w500,
          height: 1.3,
          letterSpacing: 0.3,
        ),
        // FeatureCard row titles.
        titleMedium: TextStyle(
          fontFamily: ui,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.5,
          letterSpacing: 0.3,
        ),
        // SectionCard headings.
        titleSmall: TextStyle(
          fontFamily: ui,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
          letterSpacing: 0.4,
        ),
        bodyLarge: TextStyle(
          fontFamily: ui,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.55,
          letterSpacing: 0.3,
        ),
        bodyMedium: TextStyle(
          fontFamily: ui,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
          letterSpacing: 0.3,
        ),
        bodySmall: TextStyle(
          fontFamily: ui,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.4,
          letterSpacing: 0.4,
        ),
        // Button + eyebrow labels — medium weight, tracked. These are the
        // small all-caps moments, so the baked-in tracking is generous.
        labelLarge: TextStyle(
          fontFamily: ui,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.4,
          letterSpacing: 0.8,
        ),
        labelMedium: TextStyle(
          fontFamily: ui,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.35,
          letterSpacing: 1.2,
        ),
        labelSmall: TextStyle(
          fontFamily: ui,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1.45,
          letterSpacing: 1.5,
        ),
      );

  /// The CLEAN voice — the opt-in "Clean" display style (docs/VISION.md).
  /// Same Jost family + the same M3 sizes, but re-voiced to the calm,
  /// Anthropic/Linear-style restraint the user blessed in the show_widget
  /// mockups: medium weight (not thin), and TIGHT tracking (not the wide
  /// brand tracking). Paired with sentence-case headers (ContentHeader drops
  /// its `.toUpperCase()` in clean mode) — so the hierarchy comes from size +
  /// weight + whitespace, not from caps + spacing. Only two weights show up:
  /// w400 body, w500 everything structural.
  static TextTheme cleanTextTheme() => const TextTheme(
        displayLarge: TextStyle(
          fontFamily: display,
          fontSize: 57,
          fontWeight: FontWeight.w500,
          height: 1.1,
        ),
        displayMedium: TextStyle(
          fontFamily: display,
          fontSize: 45,
          fontWeight: FontWeight.w500,
          height: 1.14,
        ),
        displaySmall: TextStyle(
          fontFamily: display,
          fontSize: 36,
          fontWeight: FontWeight.w500,
          height: 1.2,
        ),
        headlineLarge: TextStyle(
          fontFamily: display,
          fontSize: 32,
          fontWeight: FontWeight.w500,
          height: 1.25,
        ),
        headlineMedium: TextStyle(
          fontFamily: display,
          fontSize: 28,
          fontWeight: FontWeight.w500,
          height: 1.29,
        ),
        headlineSmall: TextStyle(
          fontFamily: display,
          fontSize: 24,
          fontWeight: FontWeight.w500,
          height: 1.33,
        ),
        titleLarge: TextStyle(
          fontFamily: ui,
          fontSize: 22,
          fontWeight: FontWeight.w500,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          fontFamily: ui,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.5,
        ),
        titleSmall: TextStyle(
          fontFamily: ui,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.45,
        ),
        bodyLarge: TextStyle(
          fontFamily: ui,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.55,
        ),
        bodyMedium: TextStyle(
          fontFamily: ui,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          fontFamily: ui,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          fontFamily: ui,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          height: 1.4,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontFamily: ui,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          height: 1.35,
          letterSpacing: 0.2,
        ),
        labelSmall: TextStyle(
          fontFamily: ui,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          height: 1.45,
          letterSpacing: 0.2,
        ),
      );
}

/// The spacing scale. Use instead of bare numbers so vertical rhythm is
/// consistent and a future density change is a one-file edit.
abstract final class Insets {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
}

/// The corner-radius scale. `card` (14) + `pill` (24) match the values the
/// composition primitives and glass chrome already use by hand.
abstract final class Radii {
  static const double sm = 8;
  static const double card = 14;
  static const double lg = 20;
  static const double pill = 24;
}

/// The **categorical** colour wheel for activities, games, and present-mode
/// tiles — each surface picks one as its identity colour (a brain break is
/// teal, the math game is blue, …). NOT semantic chrome (that's the
/// [ColorScheme]); this is a deliberately bright, varied set for at-a-glance
/// recognition. Centralised here so the "activity colour language" is one
/// system instead of the same Material-400 hexes copy-pasted across a dozen
/// files. All `static const` → safe to use inside `const` card lists.
abstract final class ActivityPalette {
  // Harmonized to the calm, on-brand sensibility (same family as GameAccents in
  // game.dart) — desaturated from the old Material-400 brights so the activity
  // tiles + game stages read calm, not loud. Still distinct per slot.
  static const Color blue = Color(0xFF5784A8);
  static const Color indigo = Color(0xFF6E6FA8);
  static const Color teal = Color(0xFF2A9D8F);
  static const Color tealDeep = Color(0xFF1D7A6E);
  static const Color amber = Color(0xFFC79A3E);
  static const Color yellow = Color(0xFFD4B45A);
  static const Color pink = Color(0xFFC25E7E);
  static const Color purple = Color(0xFF9A6BAE);
  static const Color deepPurple = Color(0xFF7C6BAE);
  static const Color green = Color(0xFF5E9E6B);
  static const Color cyan = Color(0xFF4F9AAE);
  static const Color lightBlue = Color(0xFF5E97B8);
  static const Color red = Color(0xFFC85A52);
  static const Color brown = Color(0xFF8B7363);
}
