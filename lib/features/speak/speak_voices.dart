import 'package:differentworld/features/speak/speak_palette.dart';
import 'package:flutter/material.dart';

/// One ElevenLabs voice offered in Speak. The [id] is NOT a secret — it's just
/// an identifier; the API key is the secret, brokered server-side by the
/// `tts-subtitles` Edge Function. The app sends the chosen [id] with the
/// prompt; the function validates its shape and caches audio per (voice, text).
@immutable
class SpeakVoice {
  const SpeakVoice({
    required this.id,
    required this.label,
    required this.palette,
    this.descriptor,
  });

  /// ElevenLabs `voice_id`.
  final String id;

  /// What the picker calls it.
  final String label;

  /// This voice's colour identity (drives the stage ambience).
  final SpeakPalette palette;

  /// A 2–3 word tonal hint shown under the name on the picker tile (e.g.
  /// "warm & steady"). Null = name only. Helps a teacher choose without
  /// auditioning each one.
  final String? descriptor;
}

/// The voices the picker offers. The first is the default. Provided by the
/// program owner — add or swap by editing this list (and nothing else: the
/// function accepts any well-formed voice_id). Each carries a colour identity;
/// rename the placeholders once you've heard them.
const List<SpeakVoice> speakVoices = <SpeakVoice>[
  SpeakVoice(
    id: 'UgBBYS2sOqTuMpoF3BR0',
    label: 'Mark',
    palette: SpeakPalette(
      bgTop: Color(0xFF15202C),
      bgBottom: Color(0xFF080D12),
      accent: Color(0xFF86B0D8), // cool slate
    ),
  ),
  SpeakVoice(
    id: 'uYXf8XasLslADfZ2MB4u',
    label: 'Hope',
    palette: SpeakPalette(
      bgTop: Color(0xFF231A11),
      bgBottom: Color(0xFF100A06),
      accent: Color(0xFFEFC78A), // warm amber
    ),
  ),
  SpeakVoice(
    id: 'EST9Ui6982FZPSi7gCHi',
    label: 'Elise',
    palette: SpeakPalette(
      bgTop: Color(0xFF231320),
      bgBottom: Color(0xFF0F0810),
      accent: Color(0xFFDD9DC6), // rose / plum
    ),
  ),
  SpeakVoice(
    id: 'fvVBPXuE7f1iX3dZLKFy',
    label: 'Dan',
    palette: SpeakPalette(
      bgTop: Color(0xFF132017),
      bgBottom: Color(0xFF070F0A),
      accent: Color(0xFF93CBA6), // deep green / sage
    ),
  ),
  // Added by id only — rename when you've heard them.
  SpeakVoice(
    id: '9gB6fhbEaYv6yh0oS2bC',
    label: 'Voice 5',
    palette: SpeakPalette(
      bgTop: Color(0xFF181530),
      bgBottom: Color(0xFF0A0816),
      accent: Color(0xFFA89BE6), // indigo / violet
    ),
  ),
  SpeakVoice(
    id: '17JdVkQHD6PE3HPohzr2',
    label: 'Voice 6',
    palette: SpeakPalette(
      bgTop: Color(0xFF0E2227),
      bgBottom: Color(0xFF061215),
      accent: Color(0xFF84D2CF), // teal / cyan
    ),
  ),
];
