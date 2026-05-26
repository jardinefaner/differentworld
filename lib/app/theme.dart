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

ThemeData buildLightTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitions,
      snackBarTheme: _snackBarTheme,
    );

ThemeData buildDarkTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitions,
      snackBarTheme: _snackBarTheme,
    );
