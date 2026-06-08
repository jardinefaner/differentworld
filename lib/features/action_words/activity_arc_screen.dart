import 'package:differentworld/features/action_words/day_run.dart';
import 'package:differentworld/features/action_words/house_timer.dart';
import 'package:differentworld/features/action_words/widgets/beat_presenter.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/arc` — **the teleprompter for teaching.** Take ANY activity (typed on
/// `/lens`, or run generic) and present its story arc — play → name → bridge →
/// question — as a castable, full-screen sequence that PROMPTS the teacher at
/// each beat (docs/VISION.md "with present/cast… like a prompt"). The app
/// holds the arc so the teacher doesn't have to: do the thing, name what it
/// secretly taught, zoom out to where else it lives, ask the one with no
/// answer. Same present surface as the day run — wears the live world's colour
/// when there is one.
class ActivityArcScreen extends ConsumerWidget {
  const ActivityArcScreen({this.activity = '', super.key});

  /// The teacher's own activity (passed via go_router `extra` from `/lens`).
  /// Empty runs the generic arc — the rails work for whatever you're about
  /// to do, named or not.
  final String activity;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(currentWorldProvider);
    final accent = world?.color ?? const Color(0xFF7C4DFF);
    final beats = buildActivityArc(
      activity,
      playSeconds: ref.watch(houseSuggestPlayMinutesProvider) * 60,
    );
    return BeatPresenter(
      beats: beats,
      accent: accent,
      emoji: world?.emoji ?? '✨',
    );
  }
}
