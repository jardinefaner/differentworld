import 'dart:async';

import 'package:differentworld/features/curricula/session_scripts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// shared_preferences IS a direct dep; the analyzer can warn spuriously across
// the pub workspace boundary (same note as the other settings providers).
import 'package:shared_preferences/shared_preferences.dart';

/// The photo session that is "today's class" — the lesson the run-day's
/// Rotation blocks fill with (docs/VISION.md: "the rotation is the photo class
/// for that day, same lesson, different rooms"). The host picks it each day; it
/// fills every Rotation block so the same lesson runs as cohorts rotate
/// through.
///
/// Device-local (the photo teacher's device drives the day — one host runs the
/// session for each rotating cohort). Defaults to the first session; the host
/// advances it from the run-day screen. A synced, run-history-aware
/// "next un-run" default is a later refinement.
final todayPhotoSessionProvider =
    AsyncNotifierProvider<TodayPhotoSessionNotifier, String>(
      TodayPhotoSessionNotifier.new,
    );

class TodayPhotoSessionNotifier extends AsyncNotifier<String> {
  static const _kKey = 'run_day.today_photo_session';

  @override
  Future<String> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_kKey);
    // Guard a stale slug (a session renamed/removed) by validating it resolves.
    if (saved != null && scriptForSession(saved) != null) return saved;
    return allSessionScripts.first.slug;
  }

  Future<void> set(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kKey, slug);
    state = AsyncData(slug);
  }
}
