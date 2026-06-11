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
  const AppColors({required this.gold});

  /// The world-signature accent. Legible on its own brightness:
  /// a soft pale gold on dark surfaces, a deeper antique gold on light.
  final Color gold;

  /// Light-theme values — the deeper gold so it reads on white.
  static const light = AppColors(gold: Color(0xFF9A7B2E));

  /// Dark-theme values — the pale gold so it reads on black.
  static const dark = AppColors(gold: Color(0xFFE6C079));

  @override
  AppColors copyWith({Color? gold}) => AppColors(gold: gold ?? this.gold);

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(gold: Color.lerp(gold, other.gold, t) ?? gold);
  }
}

/// The two bundled typefaces + the full Material text ramp built from them.
///
/// Both fonts ship in `assets/fonts/` and are declared in pubspec — they
/// are NOT fetched at runtime (that would break offline-first; see the
/// `PdfGoogleFonts` gotcha in CLAUDE.md). Speak already uses them for its
/// editorial stage; this promotes them to the whole app's voice.
abstract final class AppType {
  /// High-contrast display serif — warm, editorial, a little characterful.
  /// Used for the expressive top of the ramp (display + headline): page
  /// titles via `ContentHeader`, empty-state titles, ceremony text.
  static const display = 'Fraunces';

  /// Geometric grotesque — clean and even at small sizes. Used for
  /// everything dense + functional (title / body / label): card titles,
  /// section headings, body copy, buttons, chips. Also the global default.
  static const ui = 'SpaceGrotesk';

  /// The Material 3 ramp, re-voiced. Sizes track the M3 scale; letter-
  /// spacing is tightened at the top (the M3 defaults read loose for a
  /// warm product) and weights are nudged up so hierarchy is legible
  /// without relying on size alone. Colours are intentionally omitted so
  /// each style inherits the scheme's on-surface colour per brightness.
  static TextTheme textTheme() => const TextTheme(
        displayLarge: TextStyle(
          fontFamily: display,
          fontSize: 57,
          fontWeight: FontWeight.w600,
          height: 1.12,
          letterSpacing: -0.5,
        ),
        displayMedium: TextStyle(
          fontFamily: display,
          fontSize: 45,
          fontWeight: FontWeight.w600,
          height: 1.16,
          letterSpacing: -0.25,
        ),
        displaySmall: TextStyle(
          fontFamily: display,
          fontSize: 36,
          fontWeight: FontWeight.w600,
          height: 1.22,
        ),
        headlineLarge: TextStyle(
          fontFamily: display,
          fontSize: 32,
          fontWeight: FontWeight.w600,
          height: 1.25,
        ),
        headlineMedium: TextStyle(
          fontFamily: display,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          height: 1.29,
        ),
        // Page titles (ContentHeader) + wide empty-state titles land here —
        // the most-seen "big" style, so it carries the serif voice.
        headlineSmall: TextStyle(
          fontFamily: display,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          height: 1.33,
        ),
        titleLarge: TextStyle(
          fontFamily: ui,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          height: 1.27,
        ),
        // FeatureCard row titles.
        titleMedium: TextStyle(
          fontFamily: ui,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.5,
          letterSpacing: 0.1,
        ),
        // SectionCard headings.
        titleSmall: TextStyle(
          fontFamily: ui,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.43,
          letterSpacing: 0.1,
        ),
        bodyLarge: TextStyle(
          fontFamily: ui,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          height: 1.5,
          letterSpacing: 0.15,
        ),
        bodyMedium: TextStyle(
          fontFamily: ui,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          height: 1.43,
          letterSpacing: 0.2,
        ),
        bodySmall: TextStyle(
          fontFamily: ui,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          height: 1.33,
          letterSpacing: 0.2,
        ),
        // Button + chip labels — semibold so they pop against the surface.
        labelLarge: TextStyle(
          fontFamily: ui,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          height: 1.43,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          fontFamily: ui,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          height: 1.33,
          letterSpacing: 0.4,
        ),
        labelSmall: TextStyle(
          fontFamily: ui,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.45,
          letterSpacing: 0.4,
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
