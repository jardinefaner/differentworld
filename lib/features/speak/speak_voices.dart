import 'package:flutter/foundation.dart';

/// One ElevenLabs voice offered in Speak. The [id] is NOT a secret — it's just
/// an identifier; the API key is the secret, brokered server-side by the
/// `tts-subtitles` Edge Function. The app sends the chosen [id] with the
/// prompt; the function validates its shape and caches audio per (voice, text).
@immutable
class SpeakVoice {
  const SpeakVoice({required this.id, required this.label});

  /// ElevenLabs `voice_id`.
  final String id;

  /// What the picker calls it.
  final String label;
}

/// The voices the picker offers. The first is the default. Provided by the
/// program owner — add or swap by editing this list (and nothing else: the
/// function accepts any well-formed voice_id).
const List<SpeakVoice> speakVoices = <SpeakVoice>[
  SpeakVoice(id: 'UgBBYS2sOqTuMpoF3BR0', label: 'Mark'),
  SpeakVoice(id: 'uYXf8XasLslADfZ2MB4u', label: 'Hope'),
  SpeakVoice(id: 'EST9Ui6982FZPSi7gCHi', label: 'Elise'),
  SpeakVoice(id: 'fvVBPXuE7f1iX3dZLKFy', label: 'Dan'),
];
