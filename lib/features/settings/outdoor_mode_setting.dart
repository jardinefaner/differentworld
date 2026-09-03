import 'dart:async';

import 'package:differentworld/app/design_tokens.dart';
// CupertinoPageTransitionsBuilder moved from material/ to cupertino/route.dart
// in Flutter 3.47 — material.dart no longer re-exports it.
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Outdoor mode — a high-contrast theme variant for use in bright
/// sunlight. Jordan-persona's daily reality: hands holding a
/// clipboard, eyes squinting at glare, the standard pastel Material
/// 3 surface tones get washed out.
///
/// When ON, the active ColorScheme is rebuilt with:
///   - black backgrounds (vs the M3 light scheme's near-white)
///   - white-and-yellow accents (high luminance, high contrast)
///   - heavier text weight (bumped one step)
///   - dropped surface elevation tints (flat surfaces, no
///     surface-tint adjustment that's hard to see in glare)
///
/// Layered on top of the OS dark / light setting — outdoor mode
/// overrides both. The user can flip back via the same Settings
/// → Preferences row.
///
/// Lives alongside the text-scale setting (see
/// `lib/features/settings/text_scale_setting.dart`) in the
/// Preferences section.
enum OutdoorMode {
  /// Follow the OS theme (light or dark per system setting).
  systemDefault,

  /// Force the high-contrast "outdoor" theme regardless of OS.
  on,
}

extension OutdoorModeX on OutdoorMode {
  String get label => switch (this) {
    OutdoorMode.systemDefault => 'System default',
    OutdoorMode.on => 'High contrast (outdoor)',
  };

  String get description => switch (this) {
    OutdoorMode.systemDefault => 'Light or dark per phone setting.',
    OutdoorMode.on => 'High-contrast colors for bright sunlight + outdoor use.',
  };
}

/// Persisted choice. Watch to read the current mode; write through
/// [OutdoorModeSettingNotifier.set].
final outdoorModeProvider =
    AsyncNotifierProvider<OutdoorModeSettingNotifier, OutdoorMode>(
      OutdoorModeSettingNotifier.new,
    );

class OutdoorModeSettingNotifier extends AsyncNotifier<OutdoorMode> {
  static const _kKey = 'settings.outdoor_mode';

  @override
  Future<OutdoorMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kKey);
    return _decode(raw);
  }

  Future<void> set(OutdoorMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, _encode(mode));
    state = AsyncData(mode);
  }

  static OutdoorMode _decode(String? raw) {
    return raw == 'on' ? OutdoorMode.on : OutdoorMode.systemDefault;
  }

  static String _encode(OutdoorMode m) => m == OutdoorMode.on ? 'on' : 'system';
}

/// The high-contrast ColorScheme. Pure-black background, white +
/// safety-yellow accents — chosen for visibility against direct
/// sunlight, not for aesthetic mood. Mirrors the OSHA / DOT
/// reflective-vest palette.
ColorScheme outdoorColorScheme() {
  return const ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFFFFEB3B), // safety yellow
    onPrimary: Color(0xFF000000),
    primaryContainer: Color(0xFF1A1A00),
    onPrimaryContainer: Color(0xFFFFEB3B),
    secondary: Color(0xFFFFFFFF),
    onSecondary: Color(0xFF000000),
    secondaryContainer: Color(0xFF1A1A1A),
    onSecondaryContainer: Color(0xFFFFFFFF),
    tertiary: Color(0xFFFF9100), // safety orange
    onTertiary: Color(0xFF000000),
    tertiaryContainer: Color(0xFF1A0F00),
    onTertiaryContainer: Color(0xFFFFC074),
    error: Color(0xFFFF5252),
    onError: Color(0xFFFFFFFF),
    errorContainer: Color(0xFF1A0000),
    onErrorContainer: Color(0xFFFF8A80),
    surface: Color(0xFF000000),
    onSurface: Color(0xFFFFFFFF),
    surfaceContainerHighest: Color(0xFF1F1F1F),
    surfaceContainerHigh: Color(0xFF181818),
    surfaceContainer: Color(0xFF121212),
    surfaceContainerLow: Color(0xFF0A0A0A),
    surfaceContainerLowest: Color(0xFF000000),
    onSurfaceVariant: Color(0xFFE0E0E0),
    outline: Color(0xFFFFEB3B),
    outlineVariant: Color(0xFF333333),
    shadow: Color(0xFF000000),
    scrim: Color(0xFF000000),
    inverseSurface: Color(0xFFFFFFFF),
    onInverseSurface: Color(0xFF000000),
    inversePrimary: Color(0xFFFFEB3B),
  );
}

/// Builds the outdoor ThemeData. Pulled into a function so the
/// applier shim can call it without importing the theme file (which
/// already exports the standard light + dark themes).
ThemeData outdoorTheme() {
  final scheme = outdoorColorScheme();
  final t = AppType.textTheme();
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    fontFamily: AppType.ui,
    scaffoldBackgroundColor: scheme.surface,
    // The shared type ramp (so outdoor speaks the same voice), but with
    // heavier weight on the text that has to survive glare.
    textTheme: t.copyWith(
      bodyLarge: t.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      bodyMedium: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
      titleMedium: t.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      titleLarge: t.titleLarge?.copyWith(fontWeight: FontWeight.w800),
    ),
    // Register the palette extension so `extension<AppColors>()!` is
    // non-null in outdoor mode too. Outdoor is dark-based → the pale gold.
    extensions: const <ThemeExtension<dynamic>>[AppColors.dark],
    // No tonal elevation tints — flat surfaces read more clearly
    // when there's no shadow to anchor depth.
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      surfaceTintColor: Colors.transparent,
    ),
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.android: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      },
    ),
  );
}
