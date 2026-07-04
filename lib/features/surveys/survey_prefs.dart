import 'dart:async';

import 'package:differentworld/features/surveys/survey_templates.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Wave 149: persistent per-device survey preferences. Persisted via
/// SharedPreferences so a kid (or the staff member handing them the
/// device) doesn't have to re-tap their preferred volume / language
/// every session.
///
/// Anonymity isn't compromised — these are device-level, not tied to
/// any user identity. A different kid on the same device inherits
/// the previous kid's volume + language until they change them
/// (which is fine; the About-you page surfaces both controls so the
/// switch takes one tap).

const _kVolumeKey = 'surveys.tts.volume';
const _kLanguageKey = 'surveys.language';

/// Volume in the [0.0, 1.0] range, applied to the AudioPlayer via
/// `setVolume`. Default 1.0 (full volume). A program with a loud
/// cohort can drop it to 0.6 once and have every survey start at
/// that level.
final surveyVolumeProvider =
    AsyncNotifierProvider<SurveyVolumeNotifier, double>(
      SurveyVolumeNotifier.new,
    );

class SurveyVolumeNotifier extends AsyncNotifier<double> {
  @override
  Future<double> build() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getDouble(_kVolumeKey);
    if (v == null) return 1;
    return v.clamp(0, 1);
  }

  Future<void> set(double volume) async {
    final clamped = volume.clamp(0.0, 1.0);
    state = AsyncData(clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kVolumeKey, clamped);
  }
}

/// Language toggle for the survey-take flow. Defaults to English so a
/// monolingual program never has to think about it.
final surveyLanguageProvider =
    AsyncNotifierProvider<SurveyLanguageNotifier, SurveyLanguage>(
      SurveyLanguageNotifier.new,
    );

class SurveyLanguageNotifier extends AsyncNotifier<SurveyLanguage> {
  @override
  Future<SurveyLanguage> build() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_kLanguageKey);
    if (code == null) return SurveyLanguage.en;
    return SurveyLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => SurveyLanguage.en,
    );
  }

  Future<void> set(SurveyLanguage lang) async {
    state = AsyncData(lang);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguageKey, lang.code);
  }
}

/// Fire-and-forget setter for the volume — useful from a slider's
/// `onChanged` callback where awaiting would jank.
void persistSurveyVolume(WidgetRef ref, double volume) {
  unawaited(() async {
    try {
      await ref.read(surveyVolumeProvider.notifier).set(volume);
    } on Object {
      // best-effort
    }
  }());
}

/// Fire-and-forget setter for language.
void persistSurveyLanguage(WidgetRef ref, SurveyLanguage lang) {
  unawaited(() async {
    try {
      await ref.read(surveyLanguageProvider.notifier).set(lang);
    } on Object {
      // best-effort
    }
  }());
}
