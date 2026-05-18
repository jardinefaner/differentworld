import 'package:flutter/material.dart';

const _seed = Color(0xFF1F6FEB);

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

ThemeData buildLightTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: _seed),
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitions,
    );

ThemeData buildDarkTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seed,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
      pageTransitionsTheme: _pageTransitions,
    );
