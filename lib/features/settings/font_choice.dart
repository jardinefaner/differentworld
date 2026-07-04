import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One option in the in-app font picker (Settings → Display → Fonts).
///
/// A `bundled` option lives in `assets/fonts/` and is OFFLINE-SAFE — it renders
/// the moment it's picked, anywhere. A non-bundled option is fetched + cached
/// by `google_fonts` on first use (needs ONE online moment; degrades to the
/// system fallback until then). The DEFAULT (Fraunces + Space Grotesk) is
/// bundled, so the app's out-of-box look never depends on a fetch.
class FontOption {
  const FontOption(this.family, {this.assetFamily});

  /// The Google Fonts family name — also the display label in the picker.
  final String family;

  /// When non-null this font is bundled; use this asset family (offline-safe).
  /// (The bundled Space Grotesk asset family is `SpaceGrotesk`, no space.)
  final String? assetFamily;

  bool get bundled => assetFamily != null;
}

/// 10 DISPLAY faces — the serif/editorial voice for headlines + heroes.
const kDisplayFonts = <FontOption>[
  FontOption('Fraunces', assetFamily: 'Fraunces'),
  FontOption('Playfair Display'),
  FontOption('Lora'),
  FontOption('Cormorant'),
  FontOption('Spectral'),
  FontOption('DM Serif Display'),
  FontOption('Libre Baskerville'),
  FontOption('EB Garamond'),
  FontOption('Bitter'),
  FontOption('Jost', assetFamily: 'Jost'),
];

/// 10 BODY faces — the sans voice for titles, body, labels, UI.
const kBodyFonts = <FontOption>[
  FontOption('Space Grotesk', assetFamily: 'SpaceGrotesk'),
  FontOption('Inter'),
  FontOption('Work Sans'),
  FontOption('DM Sans'),
  FontOption('Manrope'),
  FontOption('Plus Jakarta Sans'),
  FontOption('Outfit'),
  FontOption('Figtree'),
  FontOption('Nunito Sans'),
  FontOption('Jost', assetFamily: 'Jost'),
];

/// The persisted pick — a display family + a body family (by [FontOption.family]).
class FontChoice {
  const FontChoice({required this.display, required this.body});

  final String display;
  final String body;

  /// The bundled, offline-safe default = the show_widget look.
  static const fallback = FontChoice(
    display: 'Fraunces',
    body: 'Space Grotesk',
  );

  FontChoice copyWith({String? display, String? body}) =>
      FontChoice(display: display ?? this.display, body: body ?? this.body);
}

FontOption _displayOpt(String family) => kDisplayFonts.firstWhere(
  (o) => o.family == family,
  orElse: () => kDisplayFonts.first,
);

FontOption _bodyOpt(String family) => kBodyFonts.firstWhere(
  (o) => o.family == family,
  orElse: () => kBodyFonts.first,
);

/// Render a single [TextStyle] in [opt]'s font — bundled via `fontFamily`,
/// else via `google_fonts` (fetch + cache, system fallback meanwhile).
TextStyle styleIn(FontOption opt, TextStyle base) => opt.bundled
    ? base.copyWith(fontFamily: opt.assetFamily)
    : GoogleFonts.getFont(opt.family, textStyle: base);

/// Re-skin a [base] text ramp with the chosen fonts: the display family on the
/// display + headline slots, the body family on title / body / label. Keeps the
/// base ramp's sizes / weights / tracking — only the family changes.
TextTheme applyFontChoice(TextTheme base, FontChoice c) {
  final d = _displayOpt(c.display);
  final b = _bodyOpt(c.body);
  TextStyle? dd(TextStyle? s) => s == null ? null : styleIn(d, s);
  TextStyle? bb(TextStyle? s) => s == null ? null : styleIn(b, s);
  return base.copyWith(
    displayLarge: dd(base.displayLarge),
    displayMedium: dd(base.displayMedium),
    displaySmall: dd(base.displaySmall),
    headlineLarge: dd(base.headlineLarge),
    headlineMedium: dd(base.headlineMedium),
    headlineSmall: dd(base.headlineSmall),
    titleLarge: bb(base.titleLarge),
    titleMedium: bb(base.titleMedium),
    titleSmall: bb(base.titleSmall),
    bodyLarge: bb(base.bodyLarge),
    bodyMedium: bb(base.bodyMedium),
    bodySmall: bb(base.bodySmall),
    labelLarge: bb(base.labelLarge),
    labelMedium: bb(base.labelMedium),
    labelSmall: bb(base.labelSmall),
  );
}

/// Persisted font choice. Defaults to the bundled [FontChoice.fallback] so the
/// first frame is offline-safe.
final fontChoiceProvider =
    AsyncNotifierProvider<FontChoiceNotifier, FontChoice>(
      FontChoiceNotifier.new,
    );

class FontChoiceNotifier extends AsyncNotifier<FontChoice> {
  static const _displayKey = 'font.display';
  static const _bodyKey = 'font.body';

  @override
  Future<FontChoice> build() async {
    final prefs = await SharedPreferences.getInstance();
    return FontChoice(
      display: prefs.getString(_displayKey) ?? FontChoice.fallback.display,
      body: prefs.getString(_bodyKey) ?? FontChoice.fallback.body,
    );
  }

  Future<void> setDisplay(String family) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_displayKey, family);
    state = AsyncData(
      (state.value ?? FontChoice.fallback).copyWith(display: family),
    );
  }

  Future<void> setBody(String family) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bodyKey, family);
    state = AsyncData(
      (state.value ?? FontChoice.fallback).copyWith(body: family),
    );
  }
}
