/// Wave 120 — the 5-voice cast for Deepgram Aura 2 TTS in the
/// survey-take screen. Each entry is one voice the kid can pick on
/// the first question.
///
/// Why a fixed cast (not the whole Deepgram catalog):
///   1. The Edge Function (`tts-generate`) whitelists the same 5 IDs.
///      A client picking a voice not on this list would be rejected.
///      Drift them together when adding a 6th voice.
///   2. Five fits comfortably on a phone screen as a tap-to-pick
///      grid (3 + 2 or 2 + 2 + 1). More than that crowds the
///      decision and slows the kid's first interaction.
///   3. Cache size: every (voice, question) pair generates one MP3
///      in `tts-cache/`. 5 × ~30 questions per template × ~5
///      templates ≈ 750 files total ever for the whole platform.
///      Manageable.
///
/// Why these five specifically:
///   - Thalia + Hera: two distinct female timbres (warm + confident)
///     so the kid hears variety, not "two of the same voice."
///   - Atlas + Apollo: same idea on the male side (steady + friendly).
///   - Andromeda: a calm narrator option for the kid who finds
///     character voices distracting.
library;

class AuraVoice {
  const AuraVoice({
    required this.id,
    required this.displayName,
    required this.personality,
    required this.gender,
  });

  /// The Deepgram model id — passed verbatim to the API and used as
  /// the first segment of the cache path: `${id}/${question_id}.mp3`.
  final String id;

  /// What the kid sees on the picker. Friendly persona name, not the
  /// model id ("aura-2-thalia-en" is not what a 7-year-old taps).
  final String displayName;

  /// One-line vibe descriptor used as the picker subtitle ("warm and
  /// reassuring"). Helps the kid choose without having to hear all
  /// five samples.
  final String personality;

  /// "F" / "M" / "N" — drives only the small icon on the picker tile.
  /// We don't gender-match readers to kids; this is purely a visual
  /// signal so the cast reads as varied at a glance.
  final String gender;
}

/// The 5-voice cast. Order is presentation order on the picker.
const List<AuraVoice> kAuraCast = [
  AuraVoice(
    id: 'aura-2-thalia-en',
    displayName: 'Thalia',
    personality: 'warm and reassuring',
    gender: 'F',
  ),
  AuraVoice(
    id: 'aura-2-hera-en',
    displayName: 'Hera',
    personality: 'confident and clear',
    gender: 'F',
  ),
  AuraVoice(
    id: 'aura-2-atlas-en',
    displayName: 'Atlas',
    personality: 'steady and kind',
    gender: 'M',
  ),
  AuraVoice(
    id: 'aura-2-apollo-en',
    displayName: 'Apollo',
    personality: 'friendly and bright',
    gender: 'M',
  ),
  AuraVoice(
    id: 'aura-2-andromeda-en',
    displayName: 'Andromeda',
    personality: 'calm narrator',
    gender: 'N',
  ),
];

/// Resolve a Deepgram voice id back to its presentation metadata.
/// Returns `null` if the id isn't in the cast (e.g. a row from an
/// older voice that's been retired).
AuraVoice? auraVoiceById(String? id) {
  if (id == null) return null;
  for (final v in kAuraCast) {
    if (v.id == id) return v;
  }
  return null;
}
