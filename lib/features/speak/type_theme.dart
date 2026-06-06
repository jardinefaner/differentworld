import 'package:flutter/material.dart';

/// The two typographic voices for the Speak stage (the user picks the keeper
/// with a live toggle). Each is a bundled VARIABLE font — we set its axes at
/// runtime with `fontVariations`, so the spoken word can swell in weight
/// without shipping a dozen static cuts. Fonts are declared in pubspec
/// (`assets/fonts/`), never runtime-fetched, so the stage works offline.
enum SpeakType {
  /// Fraunces — a high-contrast display serif (opsz / SOFT / WONK / wght
  /// axes). Magazine-cover elegance; weight changes read as luxurious.
  serif,

  /// Space Grotesk — a modern geometric sans (wght axis). Clean, confident,
  /// poster-like.
  grotesque,

  /// Anton — a STATIC condensed-black display face (no variable axes, single
  /// poster weight). The "bold statement" voice for Headline / Slam / Marker /
  /// Oversized. Weight-swell doesn't apply (it's always black); emphasis comes
  /// from size + colour instead.
  condensed,
}

extension SpeakTypeX on SpeakType {
  /// The bundled font family (matches pubspec `fonts: family:`).
  String get family => switch (this) {
    SpeakType.serif => 'Fraunces',
    SpeakType.grotesque => 'SpaceGrotesk',
    SpeakType.condensed => 'Anton',
  };

  /// Short human label for the toggle.
  String get label => switch (this) {
    SpeakType.serif => 'Serif',
    SpeakType.grotesque => 'Sans',
    SpeakType.condensed => 'Bold',
  };

  /// Whether the face is variable (weight can swell). Anton is static.
  bool get isVariable => this != SpeakType.condensed;

  /// Weight a quiet (un-spoken) word sits at.
  double get restWeight => switch (this) {
    SpeakType.serif => 340,
    SpeakType.grotesque => 360,
    SpeakType.condensed => 400, // unused — Anton has no weight axis
  };

  /// Weight the spoken word swells to.
  double get activeWeight => switch (this) {
    SpeakType.serif => 760,
    SpeakType.grotesque => 680,
    SpeakType.condensed => 400, // unused
  };

  /// Editorial tracking — display type is set tight; the grotesque tighter.
  double get letterSpacing => switch (this) {
    SpeakType.serif => -0.5,
    SpeakType.grotesque => -1.5,
    SpeakType.condensed => -0.5,
  };

  /// How fast the spoken word swells. Short on purpose (word windows in normal
  /// speech are ~250ms) and front-loaded (easeOutQuart) so the heaviest moment
  /// lands ON the word, not after it.
  Duration get swellDuration => switch (this) {
    SpeakType.serif => const Duration(milliseconds: 190),
    SpeakType.grotesque => const Duration(milliseconds: 140),
    SpeakType.condensed => const Duration(milliseconds: 140),
  };

  /// The next voice — the toggle cycles through all three.
  SpeakType get next => switch (this) {
    SpeakType.serif => SpeakType.grotesque,
    SpeakType.grotesque => SpeakType.condensed,
    SpeakType.condensed => SpeakType.serif,
  };

  /// All variable-font axes at a given [weight]. Fraunces gets a high optical
  /// size + neutral SOFT/WONK; Space Grotesk carries only weight; Anton is
  /// static (no axes — returns const []).
  List<FontVariation> axesAt(double weight) => switch (this) {
    SpeakType.serif => [
      FontVariation('wght', weight),
      const FontVariation('opsz', 144),
      const FontVariation('SOFT', 0),
      const FontVariation('WONK', 0),
    ],
    SpeakType.grotesque => [FontVariation('wght', weight)],
    SpeakType.condensed => const [],
  };
}
