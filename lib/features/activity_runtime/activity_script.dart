/// The activity runner (docs/ACTIVITY_RUNTIME.md §1/§3). An activity is a
/// conducted timeline of [Phase]s; [ActivityRun] is the cursor that walks
/// it. Pure data + a state machine — no UI, no timers (the surface decides
/// WHEN to [ActivityRun.advance] based on the phase's [PacingKind]).
library;

/// The closed set of interaction archetypes (§2). Each maps to one
/// full-screen, kid-mode surface.
enum ActivityMode { click, shoot, answer, create, ponder, vote, present }

/// Who holds the baton for a phase (§3). The runner is one machine that
/// supports all four; the trigger differs (a teacher tap, a timer firing,
/// a learner finishing, a wall-clock end) but the effect is the same
/// cursor move.
enum PacingKind {
  /// Everyone advances when the teacher taps (group/sync moments).
  teacher,

  /// Auto-advances after [Phase.duration].
  timer,

  /// Each learner moves independently — model as one [ActivityRun] per
  /// learner over the same [ScriptedActivity].
  perLearner,

  /// One long phase that runs until a wall-clock end (the Click burst).
  nonStop,
}

class Phase {
  const Phase({
    required this.id,
    required this.mode,
    required this.prompt,
    this.pacing = PacingKind.teacher,
    this.duration,
  });

  final String id;
  final ActivityMode mode;

  /// What the app TELLS the learner during this phase.
  final String prompt;

  final PacingKind pacing;

  /// For [PacingKind.timer] / [PacingKind.nonStop].
  final Duration? duration;
}

class ScriptedActivity {
  const ScriptedActivity({
    required this.id,
    required this.title,
    required this.phases,
  });

  final String id;
  final String title;
  final List<Phase> phases;
}

/// A cursor over one activity's phases. A SHARED instance drives a
/// teacher-/timer-paced (synchronized) run; ONE INSTANCE PER LEARNER
/// drives a per-learner (independent) run — same class, both modeled from
/// the start so independent pacing isn't a later rewrite.
class ActivityRun {
  ActivityRun(this.activity)
    : assert(activity.phases.isNotEmpty, 'an activity needs at least one phase');

  final ScriptedActivity activity;
  int _index = 0;

  int get index => _index;
  Phase get current => activity.phases[_index];

  /// True on the final phase — the defined end of the run.
  bool get isAtEnd => _index >= activity.phases.length - 1;

  /// Move to the next phase, clamped at the end. Returns true if it moved.
  /// The caller fires this per the current phase's [PacingKind].
  bool advance() {
    if (_index < activity.phases.length - 1) {
      _index++;
      return true;
    }
    return false;
  }

  void restart() => _index = 0;
}
