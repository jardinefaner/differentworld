import 'package:differentworld/features/action_words/day_run.dart';
import 'package:differentworld/shared/format/date_keys.dart';

/// The minimal shape `buildBlockRun` needs from a schedule block. The screen
/// maps a Drift `ScheduleBlock` row into this so the builder stays pure (no
/// Drift import), deterministic, and unit-testable — exactly like the other
/// run builders in day_run.dart.
typedef BlockRunInput = ({
  String blockId, // schedule_blocks.id — the drill target for a session block
  String title,
  String startAt, // ISO 8601
  String endAt, // ISO 8601
  String kind, // on_site | field_trip | break | closed
  String? notes,
  String? sessionSlug, // curriculum_session_slug, if the block runs a deck
  String? sessionTitle, // resolved lesson title, so the tile isn't generic
  BlockRunScript?
  scriptOverride, // world-tied steps that replace the generic recipe
  String? status, // planned | skipped | cancelled (null == planned)
});

/// Build the day's run-of-show from the LIVE schedule — the synthesis in
/// docs/VISION.md ("the whole day is one ordered deck — an arc from open to
/// close"). Each block becomes one [DayBeat] the teacher advances through; a
/// block carrying a curriculum session can drill into its own beat deck (the
/// screen handles the drill; the beat flags it).
///
/// Pure + deterministic so it's unit-testable and can cross the cast wire,
/// just like [buildDayRun]. The schedule's order IS the arc: blocks are sorted
/// by start time, and skipped / cancelled blocks are dropped — you don't run
/// what won't happen.
/// Beats + their source blocks, aligned by index from ONE [liveBlockOrder]
/// pass: `beats[i]` is always built from `ordered[i]`. Use this (not two
/// separate calls) whenever you need the source block behind a tapped beat —
/// it makes the alignment a structural identity rather than an assumption that
/// two independent sorts produce the same permutation.
({List<DayBeat> beats, List<BlockRunInput> ordered}) buildBlockRunAligned(
  List<BlockRunInput> blocks,
) {
  final ordered = liveBlockOrder(blocks);
  return (beats: [for (final b in ordered) _beatForBlock(b)], ordered: ordered);
}

/// The day's run-of-show beats. Convenience over [buildBlockRunAligned] for
/// callers that don't need the source blocks (e.g. tests).
List<DayBeat> buildBlockRun(List<BlockRunInput> blocks) =>
    buildBlockRunAligned(blocks).beats;

/// The blocks that will run, in beat order — skipped / cancelled dropped,
/// sorted by start time then `blockId`. The blockId tiebreaker makes it a
/// total order, so the sequence is deterministic across rebuilds (equal-start
/// blocks never reshuffle) and any two passes agree.
List<BlockRunInput> liveBlockOrder(List<BlockRunInput> blocks) =>
    [
      for (final b in blocks)
        if (b.status != 'skipped' && b.status != 'cancelled') b,
    ]..sort((a, b) {
      final byStart = a.startAt.compareTo(b.startAt);
      return byStart != 0 ? byStart : a.blockId.compareTo(b.blockId);
    });

DayBeat _beatForBlock(BlockRunInput b) {
  final start = DateTime.tryParse(b.startAt)?.toLocal();
  final end = DateTime.tryParse(b.endAt)?.toLocal();
  final timeLabel = (start != null && end != null)
      ? '${timeOfDay(start)} – ${timeOfDay(end)}'
      : '';
  final rawSeconds = (start != null && end != null)
      ? end.difference(start).inSeconds
      : 0;
  // Cap at 6h so a malformed/overnight range can't seed an absurd timer.
  final seconds = rawSeconds < 0
      ? 0
      : (rawSeconds > 21600 ? 21600 : rawSeconds);
  final hasSession = (b.sessionSlug ?? '').trim().isNotEmpty;
  final sessionTitle = (b.sessionTitle ?? '').trim();
  final notes = (b.notes ?? '').trim();
  // A session block runs the photo deck; otherwise a routine run-script fills
  // it (the steps + tools to run THIS block), so no slide is just a title. A
  // world-tied override (e.g. an icebreaker keyed to this week's world) wins
  // over the generic recipe.
  final recipe = hasSession
      ? null
      : (b.scriptOverride ?? blockRunScript(b.kind, b.title));
  // A 'closed' block is the day's handoff beat; everything else is a do-it.
  final kind = b.kind == 'closed' ? DayBeatKind.close : DayBeatKind.activity;

  final String sub;
  final List<String> lines;
  if (hasSession) {
    sub = sessionTitle.isNotEmpty ? 'Photo class · $sessionTitle' : notes;
    lines = const ['▶ Open to run the lesson'];
  } else if (recipe != null) {
    sub = recipe.tools.isEmpty ? notes : 'Bring: ${recipe.tools.join(', ')}';
    lines = recipe.steps;
  } else {
    sub = notes;
    lines = const [];
  }

  return DayBeat(
    kind: kind,
    label: timeLabel,
    big: b.title.trim().isEmpty ? 'Untitled block' : b.title.trim(),
    sub: sub,
    lines: lines,
    suggestedSeconds: seconds,
    energy: blockEnergy(b.kind, b.title),
  );
}

/// A run-script for a routine / non-session block — the steps to run it + the
/// tools to bring, so the slide carries everything to run THAT block instead of
/// a generic title.
typedef BlockRunScript = ({List<String> steps, List<String> tools});

/// The everyday-routine families a non-session block can be — the unit a
/// director edits in the routine-script editor (features/action_words/
/// routine_script_editor_screen.dart). A block is matched to one of these by
/// its title (+ the `closed` schedule kind for pickup); each has a baked-in
/// default recipe a program can override per space. Declaration order IS the
/// match precedence (arrival before meal before …).
enum RoutineKind {
  arrival('Arrival', [
    'arrival',
    'check-in',
    'check in',
    'drop-off',
    'drop off',
  ]),
  meal('Meals', ['breakfast', 'lunch', 'snack', 'meal']),
  rest('Rest', ['rest', 'nap', 'quiet time']),
  pickup('Pickup', ['pickup', 'goodbye', 'dismissal']),
  transition('Transition', ['transition']),
  welcome('Welcome / circle', [
    'icebreaker',
    'welcome',
    'circle',
    'morning meeting',
  ]),
  freePlay('Free play', [
    'free play',
    'free',
    'outdoor',
    'outside',
    'recess',
    'play',
  ]);

  const RoutineKind(this.label, this.keywords);

  /// Human label for the editor's routine picker.
  final String label;

  /// Title keywords that match a block to this routine.
  final List<String> keywords;

  static RoutineKind? fromName(String? name) {
    for (final r in RoutineKind.values) {
      if (r.name == name) return r;
    }
    return null;
  }
}

/// Which routine a block is, from its schedule kind + title — null when no
/// family matches (the block keeps its title + notes). Rotation / session
/// blocks don't use this; they run the photo deck. The match order is the
/// precedence preserved from the original keyword cascade, so behaviour is
/// unchanged.
RoutineKind? classifyRoutine(String kind, String title) {
  final t = title.toLowerCase();
  bool has(List<String> words) => words.any(t.contains);
  for (final r in RoutineKind.values) {
    if (r == RoutineKind.pickup) {
      if (kind == 'closed' || has(r.keywords)) return r;
    } else if (has(r.keywords)) {
      return r;
    }
  }
  return null;
}

/// The baked-in default recipe for a routine — the steps + tools a program
/// starts from (and can override in the editor). Exhaustive over [RoutineKind].
BlockRunScript defaultRoutineScript(RoutineKind r) => switch (r) {
  RoutineKind.arrival => (
    steps: [
      'Greet each kid by name at the door',
      'Sign in + mark attendance',
      'Settle into a quiet choice',
    ],
    tools: ['sign-in sheet'],
  ),
  RoutineKind.meal => (
    steps: [
      'Wash hands',
      'Hand out / serve',
      'Eat together — table talk',
      'Clean up together',
    ],
    tools: ['the food', 'wipes'],
  ),
  RoutineKind.rest => (
    steps: [
      'Lights low, calm music on',
      'Mats / quiet spots',
      'Rest or a quiet activity',
      'Wake gently',
    ],
    tools: ['mats', 'soft music'],
  ),
  RoutineKind.pickup => (
    steps: [
      'Pack up belongings',
      'Goodbye circle — one win each',
      'Check out each kid to their guardian',
    ],
    tools: ['sign-out sheet', "today's reveal"],
  ),
  RoutineKind.transition => (
    steps: [
      'Eyes up',
      'Clean up the space',
      'Move calmly / line up',
      'Breathe together',
    ],
    tools: const [],
  ),
  RoutineKind.welcome => (
    steps: [
      'Quick name + energy check',
      'One thing about your day',
      "Claim today's verb",
    ],
    tools: const [],
  ),
  RoutineKind.freePlay => (
    steps: [
      'Set the choices out',
      'Step back — let them lead',
      'Circulate + capture moments',
      '5-minute warning before cleanup',
    ],
    tools: const [],
  ),
};

/// The BAKED-IN run-script for a block, or null when no routine matches — it
/// keeps its title + notes. A program's per-space override is layered on at the
/// call site (block_run_screen passes it as `scriptOverride`); this stays a
/// pure function of (kind, title) so the builder + tests don't need a Ref.
BlockRunScript? blockRunScript(String kind, String title) {
  final r = classifyRoutine(kind, title);
  return r == null ? null : defaultRoutineScript(r);
}

/// A recipe's steps as a runnable sub-deck — one beat per step, castable like
/// any beat deck. Pure, so the screen can build it from either the generic
/// recipe or a world-tied override. Empty when [recipe] is null.
List<DayBeat> recipeBeats(BlockRunScript? recipe, String title) {
  if (recipe == null) return const [];
  final n = recipe.steps.length;
  return [
    for (var i = 0; i < n; i++)
      DayBeat(
        kind: DayBeatKind.activity,
        label: '$title · ${i + 1}/$n',
        big: recipe.steps[i],
        sub: i == 0 && recipe.tools.isNotEmpty
            ? 'Bring: ${recipe.tools.join(', ')}'
            : '',
      ),
  ];
}

/// A routine block's steps as a runnable sub-deck — eyes up → clean up →
/// breathe (the generic recipe). Empty when the block has no recipe.
List<DayBeat> routineRunBeats(String kind, String title) =>
    recipeBeats(blockRunScript(kind, title), title);

/// A coarse energy level (0..1) for a block, from its kind + a light title
/// keyword scan — so the day's order draws an arc without anyone hand-tuning it
/// yet (an explicit per-block energy field is a later slice). calm ≈ 0.3,
/// active ≈ 0.6, peak ≈ 0.9.
double blockEnergy(String kind, String title) {
  if (kind == 'closed') return 0.18;
  if (kind == 'break') return 0.32;
  if (kind == 'field_trip') return 0.9;
  final t = title.toLowerCase();
  const peak = [
    'play', 'outside', 'recess', 'gym', 'free', 'run', 'dance', 'sport',
    'ball', 'game', 'active', 'move', //
  ];
  const calm = [
    'circle', 'story', 'rest', 'quiet', 'calm', 'nap', 'arrival', 'welcome',
    'meeting', 'reflect', 'wind', 'snack', 'read', 'journal', //
  ];
  if (peak.any(t.contains)) return 0.9;
  if (calm.any(t.contains)) return 0.32;
  return 0.6; // a generic do-it block — mid-high
}
