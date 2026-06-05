import 'package:flutter/material.dart';

/// A voice's colour identity. Picking a voice also sets the *mood*: the living
/// background washes toward this palette, and the spoken word picks up a faint
/// glow in the accent. Editorial restraint holds — the body text stays
/// near-white for legibility; the colour lives in the AMBIENCE, not the ink.
@immutable
class SpeakPalette {
  const SpeakPalette({
    required this.bgTop,
    required this.bgBottom,
    required this.accent,
  });

  /// Background gradient poles — deep, near-black, tinted toward the voice so
  /// white text keeps its contrast.
  final Color bgTop;
  final Color bgBottom;

  /// The hue the active word glows in (a soft shadow, never the fill).
  final Color accent;

  /// Default ambience before a voice is in play / for the neutral stage.
  static const SpeakPalette neutral = SpeakPalette(
    bgTop: Color(0xFF14151F),
    bgBottom: Color(0xFF090A10),
    accent: Color(0xFFAEB6C6),
  );
}
