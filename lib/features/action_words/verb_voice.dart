import 'package:differentworld/features/action_words/verbs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// On-device voiceover for the action words — so a pre-reader in the 4–6
/// cohort can HEAR each verb (the pick screen is unreadable to them
/// otherwise). Wraps `flutter_tts` → the platform's built-in speech engine,
/// so it needs no network (offline-first) and no bundled audio.
///
/// Owned by the screen that uses it (created in `initState`, [stop]ped in
/// `dispose`). Failures are swallowed: silent audio is a degraded experience,
/// never a broken flow — a kid mid-pick must not hit an error because the
/// device has no TTS engine.
class VerbVoice {
  VerbVoice();

  final FlutterTts _tts = FlutterTts();
  Future<void>? _ready;

  Future<void> _ensureReady() => _ready ??= () async {
    await _tts.setLanguage('en-US');
    // Slower + slightly brighter than default so a young child can follow
    // a single word.
    await _tts.setSpeechRate(0.42);
    await _tts.setPitch(1.1);
  }();

  /// Speak a verb as "{label}. {lens}." — e.g. "Help. Do it together."
  Future<void> speakVerb(Verb verb) => _say('${verb.label}. ${verb.lens}.');

  /// Speak an arbitrary kid-facing line (e.g. the celebration recap).
  Future<void> say(String text) => _say(text);

  Future<void> _say(String text) async {
    try {
      await _ensureReady();
      // Cut off the previous word so rapid taps feel responsive.
      await _tts.stop();
      await _tts.speak(text);
    } on Object catch (e, st) {
      if (kDebugMode) debugPrint('[verb-voice] speak failed: $e\n$st');
    }
  }

  /// Stop any in-flight speech. Call from the owner's dispose.
  Future<void> stop() async {
    try {
      await _tts.stop();
    } on Object catch (e, st) {
      if (kDebugMode) debugPrint('[verb-voice] stop failed: $e\n$st');
    }
  }
}
