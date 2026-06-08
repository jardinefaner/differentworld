import 'package:differentworld/features/action_words/day_run.dart';
import 'package:differentworld/features/action_words/thinking_games.dart';
import 'package:differentworld/features/action_words/widgets/beat_presenter.dart';
import 'package:differentworld/features/action_words/world_rules.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// `/play-today` — **the day, on rails.** One ordered, full-screen run of show
/// for the live room: the world, its verbs + rule, Watch → Do, the Big
/// Thinking move (play → name → bridge → question), the activity, then the
/// closing handoff — assembled from *this week × this room* (docs/VISION.md
/// "The day, on rails"). The teacher just advances it; no hunting across
/// screens. Renders through the shared [BeatPresenter] (the one immersive
/// present surface), and is the same surface the device can mirror/cast.
class DayRunScreen extends ConsumerWidget {
  const DayRunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final world = ref.watch(currentWorldProvider);
    if (world == null) {
      // No live world (journey not set up) — nothing to run.
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'No world is live yet',
                  style: TextStyle(color: Colors.white, fontSize: 22),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Set the journey start date to play the day.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 15),
                ),
                const SizedBox(height: 20),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: const Text('Close'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final weekThinking = ref.watch(thisWeekThinkingProvider);
    final beats = buildDayRun(
      world: world,
      rules: rulesForWorld(world.id),
      thinking: weekThinking.isEmpty ? null : weekThinking.first,
    );

    return BeatPresenter(
      beats: beats,
      accent: world.color,
      emoji: world.emoji,
    );
  }
}
