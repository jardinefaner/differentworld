/// Wave 120 — the voice cast for Deepgram Aura 2 TTS in the
/// survey-take screen. Each entry is one voice the kid can pick on
/// the About-you page.
///
/// Wave 149: expanded to include Spanish (Latin American) Aura voices
/// + a `language` field on AuraVoice so the About-you page can
/// filter the picker to match the kid's chosen language toggle.
///
/// Why a fixed cast (not the whole Deepgram catalog):
///   1. The Edge Function (`tts-generate`) whitelists the same IDs.
///      A client picking a voice not on this list would be rejected.
///      Drift them together when adding a new voice.
///   2. ~5 per language fits comfortably on a phone screen as a
///      tap-to-pick list. More than that crowds the decision and
///      slows the kid's first interaction.
///   3. Cache size: every (voice, question) pair generates one MP3
///      in `tts-cache/`. Bounded by N voices × M templates × Q
///      questions.
library;

class AuraVoice {
  const AuraVoice({
    required this.id,
    required this.displayName,
    required this.personality,
    required this.gender,
    required this.language,
  });

  /// The Deepgram model id — passed verbatim to the API and used as
  /// the first segment of the cache path: `${id}/${question_id}.mp3`.
  final String id;

  /// What the kid sees on the picker. Friendly persona name, not the
  /// model id ("aura-2-thalia-en" is not what a 7-year-old taps).
  final String displayName;

  /// One-line vibe descriptor used as the picker subtitle ("warm and
  /// reassuring"). Helps the kid choose without having to hear all
  /// samples.
  final String personality;

  /// "F" / "M" / "N" — drives only the small icon on the picker tile.
  /// We don't gender-match readers to kids; this is purely a visual
  /// signal so the cast reads as varied at a glance.
  final String gender;

  /// Two-letter language code ('en', 'es'). Wave 149: the About-you
  /// page filters `kAuraCast` by this so the kid only sees voices in
  /// the language they picked at the top of the page.
  final String language;
}

/// The full voice cast. Order is presentation order within each
/// language; filtering by language happens at the picker.
const List<AuraVoice> kAuraCast = [
  // -- English (en-US) --
  AuraVoice(
    id: 'aura-2-thalia-en',
    displayName: 'Thalia',
    personality: 'warm and reassuring',
    gender: 'F',
    language: 'en',
  ),
  AuraVoice(
    id: 'aura-2-hera-en',
    displayName: 'Hera',
    personality: 'confident and clear',
    gender: 'F',
    language: 'en',
  ),
  AuraVoice(
    id: 'aura-2-atlas-en',
    displayName: 'Atlas',
    personality: 'steady and kind',
    gender: 'M',
    language: 'en',
  ),
  AuraVoice(
    id: 'aura-2-apollo-en',
    displayName: 'Apollo',
    personality: 'friendly and bright',
    gender: 'M',
    language: 'en',
  ),
  AuraVoice(
    id: 'aura-2-andromeda-en',
    displayName: 'Andromeda',
    personality: 'calm narrator',
    gender: 'N',
    language: 'en',
  ),

  // -- Spanish (es-LA — Latin American) --
  // Personalities written in Spanish so the picker reads natively
  // when the kid has switched the survey to ES.
  AuraVoice(
    id: 'aura-2-celeste-es',
    displayName: 'Celeste',
    personality: 'cálida y amable',
    gender: 'F',
    language: 'es',
  ),
  AuraVoice(
    id: 'aura-2-estrella-es',
    displayName: 'Estrella',
    personality: 'clara y segura',
    gender: 'F',
    language: 'es',
  ),
  AuraVoice(
    id: 'aura-2-nestor-es',
    displayName: 'Néstor',
    personality: 'tranquilo y amistoso',
    gender: 'M',
    language: 'es',
  ),
  AuraVoice(
    id: 'aura-2-javier-es',
    displayName: 'Javier',
    personality: 'animado y claro',
    gender: 'M',
    language: 'es',
  ),
  AuraVoice(
    id: 'aura-2-sirio-es',
    displayName: 'Sirio',
    personality: 'narrador calmado',
    gender: 'N',
    language: 'es',
  ),
];

/// Voices in a given language. The About-you page calls this with the
/// kid's current language toggle to show only the matching tiles.
List<AuraVoice> auraVoicesForLanguage(String language) =>
    kAuraCast.where((v) => v.language == language).toList(growable: false);

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
