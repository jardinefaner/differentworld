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
}

extension SpeakTypeX on SpeakType {
  /// The bundled font family (matches pubspec `fonts: family:`).
  String get family => switch (this) {
        SpeakType.serif => 'Fraunces',
        SpeakType.grotesque => 'SpaceGrotesk',
      };

  /// Short human label for the toggle.
  String get label => switch (this) {
        SpeakType.serif => 'Serif',
        SpeakType.grotesque => 'Sans',
      };

  /// Weight a quiet (un-spoken) word sits at.
  double get restWeight => switch (this) {
        SpeakType.serif => 340,
        SpeakType.grotesque => 360,
      };

  /// Weight the spoken word swells to.
  double get activeWeight => switch (this) {
        SpeakType.serif => 760,
        SpeakType.grotesque => 680,
      };

  /// Editorial tracking — display type is set tight; the grotesque tighter.
  double get letterSpacing => switch (this) {
        SpeakType.serif => -0.5,
        SpeakType.grotesque => -1.5,
      };

  /// How fast the spoken word swells. Short on purpose (word windows in normal
  /// speech are ~250ms) and front-loaded (easeOutQuart) so the heaviest moment
  /// lands ON the word, not after it. Per-voice: the serif luxuriates a beat
  /// longer; the grotesque snaps — so the two read differently in MOTION, not
  /// just in glyph.
  Duration get swellDuration => switch (this) {
        SpeakType.serif => const Duration(milliseconds: 190),
        SpeakType.grotesque => const Duration(milliseconds: 140),
      };

  /// The other voice — the toggle flips between the two.
  SpeakType get other => switch (this) {
        SpeakType.serif => SpeakType.grotesque,
        SpeakType.grotesque => SpeakType.serif,
      };

  /// All variable-font axes at a given [weight]. Fraunces gets a high optical
  /// size (it's shown large) and neutral SOFT/WONK; Space Grotesk only carries
  /// the weight axis.
  List<FontVariation> axesAt(double weight) => switch (this) {
        SpeakType.serif => [
            FontVariation('wght', weight),
            const FontVariation('opsz', 144),
            const FontVariation('SOFT', 0),
            const FontVariation('WONK', 0),
          ],
        SpeakType.grotesque => [FontVariation('wght', weight)],
      };
}
