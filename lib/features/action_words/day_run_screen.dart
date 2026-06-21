import 'package:differentworld/features/action_words/day_run.dart';
import 'package:differentworld/features/action_words/house_timer.dart';
import 'package:differentworld/features/action_words/thinking_games.dart';
import 'package:differentworld/features/action_words/widgets/beat_presenter.dart';
import 'package:differentworld/features/action_words/world_rules.dart';
import 'package:differentworld/features/action_words/world_schedule.dart';
import 'package:differentworld/features/today/today_providers.dart';
import 'package:differentworld/shared/widgets/edge_scaffold.dart';
import 'package:differentworld/shared/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
      // No live world (the journey isn't set up yet). NOT a dead-end: point the
      // teacher at the setup surface (/this-week owns "Set up the journey" + the
      // start-date picker) AND keep a visible "Close" exit — this can be a cold
      // deep link with nothing to pop, so we never rely on the system back
      // gesture alone. EdgeScaffold — NOT a raw black Scaffold — so the empty
      // state clears the floating chrome and follows OS light/dark. BeatPresenter
      // owns immersive on the happy path below.
      return EdgeScaffold(
        body: EmptyState(
          icon: Icons.map_outlined,
          title: 'No world is live yet',
          message: 'Set your journey start date and the day plays itself.',
          action: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton.icon(
                onPressed: () => context.push('/this-week'),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('Set up your journey'),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () {
                  final nav = Navigator.of(context);
                  if (nav.canPop()) {
                    nav.pop();
                  } else {
                    context.go('/');
                  }
                },
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      );
    }

    final weekThinking = ref.watch(thisWeekThinkingProvider);
    final beats = buildDayRun(
      world: world,
      rules: rulesForWorld(world.id),
      thinking: weekThinking.isEmpty ? null : weekThinking.first,
      playSeconds: ref.watch(houseSuggestPlayMinutesProvider) * 60,
    );

    // Open where the day actually is — a mid-program tap lands on the doing
    // part, a pickup-time tap on the closing handoff — so the teacher isn't
    // swiping past the morning to reach now. The visible controls make
    // stepping back to an earlier beat one tap away.
    final phase =
        ref.watch(dayPhaseProvider).value ?? DayPhase.fromClock(DateTime.now());
    final today = todayIso();
    // ref.read (not watch): this is a mount-time value. Re-opening the run
    // resumes the remembered beat; while it's up we don't want to yank the
    // page when the remembered index updates.
    final resume = ref.read(dayRunResumeProvider);

    return BeatPresenter(
      beats: beats,
      accent: world.color,
      emoji: world.emoji,
      initialBeat: dayRunStartIndex(
        beats: beats,
        phase: phase,
        today: today,
        resume: resume,
      ),
      onBeatChanged: (i) => ref
          .read(dayRunResumeProvider.notifier)
          .remember(date: today, index: i),
    );
  }

  /// Map the wall-clock phase to the beat the run should open on. Public +
  /// pure so it's unit-testable without pumping the immersive surface.
  static int initialBeatForPhase(List<DayBeat> beats, DayPhase phase) {
    int firstOf(List<DayBeatKind> kinds) {
      for (final k in kinds) {
        final i = beats.indexWhere((b) => b.kind == k);
        if (i >= 0) return i;
      }
      return 0;
    }

    switch (phase) {
      case DayPhase.prep:
      case DayPhase.arrival:
        return 0; // open the world from the top
      case DayPhase.program:
        // The doing part: the Big Thinking play, else the activity, else watch.
        return firstOf(const [
          DayBeatKind.play,
          DayBeatKind.activity,
          DayBeatKind.watch,
        ]);
      case DayPhase.pickup:
      case DayPhase.closed:
        // The closing handoff (→ the reveal).
        final i = beats.lastIndexWhere((b) => b.kind == DayBeatKind.close);
        return i < 0 ? 0 : i;
    }
  }
}

/// Remembers where the teacher left the day run so re-opening resumes there
/// instead of teleporting to the current phase's beat (the program→pickup jump
/// the pressure-test caught). In-memory, per session — surviving a cold
/// restart is a deferred nicety.
@immutable
class DayRunResume {
  const DayRunResume({required this.date, required this.index});
  final String date;
  final int index;
}

final dayRunResumeProvider =
    NotifierProvider<DayRunResumeNotifier, DayRunResume?>(
      DayRunResumeNotifier.new,
    );

class DayRunResumeNotifier extends Notifier<DayRunResume?> {
  @override
  DayRunResume? build() => null;

  void remember({required String date, required int index}) =>
      state = DayRunResume(date: date, index: index);
}

/// Where the day run opens: the remembered beat if it's from [today] and still
/// in range, otherwise the beat for the current [phase]. Pure + testable.
int dayRunStartIndex({
  required List<DayBeat> beats,
  required DayPhase phase,
  required String today,
  DayRunResume? resume,
}) {
  if (resume != null &&
      resume.date == today &&
      resume.index >= 0 &&
      resume.index < beats.length) {
    return resume.index;
  }
  return DayRunScreen.initialBeatForPhase(beats, phase);
}
