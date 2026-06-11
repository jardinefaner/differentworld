import 'package:differentworld/app/design_tokens.dart';
import 'package:flutter/material.dart';

// Warm teal — picked over the prior developer-blue (`0xFF1F6FEB`) so
// every container / pill / status tint resolved by `ColorScheme.fromSeed`
// reads as "afterschool program for children" rather than "GitHub /
// Linear / Jira." One-line swap; everything else in the app derives
// from this single value so the whole product shifts in lock-step:
// glass pills, primaryContainer tints, FeatureCard / SectionCard
// .featured / .selected tones, PersonAvatar initials palette,
// FloatingHamburger / FloatingBack pill chrome, login wordmark
// gradient.
const _seed = Color(0xFF2A9D8F);

// Warm amber used ONLY to seed the scheme's tertiary ramp. M3 generates
// the whole tonal palette from a single hue, which leaves tertiary a
// cool teal-derived colour — flat. Grafting a tertiary ramp generated
// from this amber gives the "all good / affirmative" tones (SectionCard
// .success, FeatureCard.success → `tertiaryContainer`) genuine warmth,
// while staying inside M3's contrast guarantees (the roles come from a
// real `fromSeed` pass, not a hand-picked pair that might fail AA).
const _warmSeed = Color(0xFFC79A3E);

/// Cupertino-style slide on every platform. M3's default Android
/// transitions (zoom / fade-through) feel sluggish on a 60 Hz panel;
/// the iOS slide is ~350 ms with a tight curve and reads as snappy
/// even when the device is heavily loaded. Also enables the built-in
/// swipe-from-left back gesture on Android via Material's
/// CupertinoPageTransitionsBuilder shim.
const _pageTransitions = PageTransitionsTheme(
  builders: <TargetPlatform, PageTransitionsBuilder>{
    TargetPlatform.android: CupertinoPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
    TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
    TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
  },
);

// Wave 107: floating snackbars on every form factor. The default
// `SnackBarBehavior.fixed` pins a snackbar to the bottom-edge of
// the viewport — on a 1440-tall desktop the "Saved" toast fires
// 1300dp below where the user's eye is. Floating + a capped width
// + a small bottom margin lets it sit closer to the action that
// triggered it on phone too. The width cap centers it on desktop.
const _snackBarTheme = SnackBarThemeData(
  behavior: SnackBarBehavior.floating,
  width: 480,
  insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
);

/// The app's [ColorScheme] for a given brightness: the teal seed for the
/// bulk of the palette, with a warm amber ramp grafted into the tertiary
/// roles (see [_warmSeed]). Both halves come from `ColorScheme.fromSeed`,
/// so every role keeps its M3-guaranteed contrast pairing.
ColorScheme appColorScheme(Brightness brightness) {
  final base = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  final warm =
      ColorScheme.fromSeed(seedColor: _warmSeed, brightness: brightness);
  return base.copyWith(
    tertiary: warm.primary,
    onTertiary: warm.onPrimary,
    tertiaryContainer: warm.primaryContainer,
    onTertiaryContainer: warm.onPrimaryContainer,
  );
}

// ── Component shapes / sizes, expressed once ──────────────────────────
//
// These give buttons, fields, and chips a single coherent shape language
// instead of M3's defaults (which differ subtly per component). Buttons
// also get a ≥48dp min height so every primary action clears the touch-
// target floor (CLAUDE.md a11y rule) without each call site remembering.

final _buttonShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(Radii.card),
);

ButtonStyle _baseButtonStyle() => ButtonStyle(
      shape: WidgetStatePropertyAll(_buttonShape),
      minimumSize: const WidgetStatePropertyAll(Size(64, 48)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: Insets.xl, vertical: Insets.md),
      ),
      // labelLarge carries the button voice (Space Grotesk, semibold).
      textStyle: WidgetStatePropertyAll(AppType.textTheme().labelLarge),
    );

/// Assembles a full [ThemeData] from a [ColorScheme]. Light + dark differ
/// only by the scheme they pass in; the type ramp, component themes, and
/// the [AppColors] extension are shared.
///
/// Deliberately does NOT theme bottom-sheet / dialog / drawer backgrounds —
/// those opt into the translucent glass surface per-call via
/// `showGlassSheet` / `GlassPanel`, and a global translucent background
/// would break every solid dialog (see the glass-chrome note in CLAUDE.md).
ThemeData _themeFrom(ColorScheme scheme) {
  final text = AppType.textTheme();
  final isDark = scheme.brightness == Brightness.dark;
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    // Global default so any stray `Text` without a named style still
    // speaks Space Grotesk, not Roboto. Named styles in [text] override
    // per-role (display + headline switch to Fraunces).
    fontFamily: AppType.ui,
    textTheme: text,
    pageTransitionsTheme: _pageTransitions,
    snackBarTheme: _snackBarTheme,
    extensions: <ThemeExtension<dynamic>>[
      if (isDark) AppColors.dark else AppColors.light,
    ],
    filledButtonTheme: FilledButtonThemeData(style: _baseButtonStyle()),
    elevatedButtonTheme: ElevatedButtonThemeData(style: _baseButtonStyle()),
    outlinedButtonTheme: OutlinedButtonThemeData(style: _baseButtonStyle()),
    textButtonTheme: TextButtonThemeData(
      style: _baseButtonStyle().copyWith(
        // Text buttons are tighter — they sit inline, not as slabs.
        padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: Insets.md, vertical: Insets.sm),
        ),
      ),
    ),
    // One field shape everywhere: a filled, softly-rounded input that
    // reads as a surface, with the focus state carried by the primary
    // colour rather than a heavy outline.
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: Insets.lg,
        vertical: Insets.md,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(Radii.card),
        borderSide: BorderSide(color: scheme.primary, width: 2),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: text.labelLarge,
      padding: const EdgeInsets.symmetric(
        horizontal: Insets.md,
        vertical: Insets.sm,
      ),
    ),
    // The app composes cards from `Material` (FeatureCard / SectionCard);
    // this only governs raw `Card` usage, but keeps it on-language: no
    // tonal tint creep, the shared card radius.
    cardTheme: CardThemeData(
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.card),
      ),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      thickness: 1,
      space: Insets.lg,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.lg),
      ),
    ),
  );
}

ThemeData buildLightTheme() => _themeFrom(appColorScheme(Brightness.light));

ThemeData buildDarkTheme() => _themeFrom(appColorScheme(Brightness.dark));
