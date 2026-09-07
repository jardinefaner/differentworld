import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS listed as a direct dep in pubspec.yaml; the
// analyzer sometimes warns spuriously across pub workspace boundaries.
import 'package:shared_preferences/shared_preferences.dart';

/// Whether a survey may read its questions aloud in a synthetic voice.
///
/// **Defaults to OFF**, and unlike the layout toggles that default is a
/// product line rather than a preference: docs/AI_BOUNDARY.md says the app
/// keeps AI backstage and people frontstage, and a machine voice reading to a
/// child is the machine on the stage.
///
/// It is a TOGGLE rather than a deletion because of how surveys are actually
/// run — **one child at a time, with an adult sitting there.** That changes
/// the failure mode the boundary is really about: an unsupervised voice
/// telling a child something wrong is unrecoverable, while a voice a teacher
/// is listening to alongside them is a supervised aid the adult can correct
/// mid-sentence. Supervision is what makes it defensible, so a program that
/// needs it can switch it on knowingly.
///
/// What is NOT defensible is the way it shipped: the voice was COMPULSORY —
/// a child could not start a survey without first picking one. That made a
/// model the price of entry to a kid-facing screen, which is the boundary
/// crossed by default rather than by decision.
///
/// The principle-correct answer for pre-readers is still a person: a teacher
/// recording each question once, replayed offline forever. This toggle makes
/// the DEFAULT honest; it does not build that.
final surveyReadAloudProvider =
    AsyncNotifierProvider<SurveyReadAloudNotifier, bool>(
      SurveyReadAloudNotifier.new,
    );

class SurveyReadAloudNotifier extends AsyncNotifier<bool> {
  static const _kKey = 'settings.survey_read_aloud';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kKey) ?? false;
  }

  Future<void> set({required bool value}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kKey, value);
    state = AsyncData(value);
  }
}
