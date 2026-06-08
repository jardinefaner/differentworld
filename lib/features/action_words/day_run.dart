import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/thinking_games.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/world_rules.dart';
import 'package:flutter/foundation.dart';

/// One beat in the day's **run of show** — a single full-screen slide the
/// teacher advances through (docs/VISION.md "The day, on rails"). The teacher
/// stops hunting across screens; the day plays itself in order.
enum DayBeatKind {
  open, // the world hero
  question, // the world's question
  verbs, // this week's featured verbs
  rule, // the rule of this world
  watch, // a Watch → Do video cue
  play, // Big Thinking — play it
  name, // Big Thinking — name it (the spell)
  bridge, // Big Thinking — where else (the zoom-out)
  ask, // Big Thinking — the question for the Wall
  activity, // the do-it activity menu
  close, // the closing handoff (→ reveal)
}

/// A single presentable beat. Pure data — the screen renders it; this carries
/// no widgets so the run can be built + tested (and later cast) headless.
@immutable
class DayBeat {
  const DayBeat({
    required this.kind,
    this.label = '',
    this.big = '',
    this.sub = '',
    this.lines = const [],
  });

  final DayBeatKind kind;

  /// Small caption above the headline ("WEEK 4 · WATCH · 3 MIN").
  final String label;

  /// The headline — the thing read from across the room.
  final String big;

  /// Optional supporting line under the headline.
  final String sub;

  /// For list beats (verbs, the bridge steps, the activity menu).
  final List<String> lines;
}

/// Assemble the day's run from the live context — the curriculum [world], its
/// [rules], and this week's [thinking] game (the headline one). Pure +
/// deterministic so it's unit-testable and can later cross the cast wire.
///
/// The order IS the day's arc — open the world, name the verbs + the rule,
/// watch, then the Big Thinking move (play → name → bridge → question), then
/// go do it, then hand off to the closing reveal. Time-bound by construction;
/// a future pass can start the run at the beat for the current phase.
List<DayBeat> buildDayRun({
  required CurriculumWorld world,
  List<WorldRule> rules = const [],
  ThinkingGame? thinking,
}) {
  final verbLines = <String>[
    for (final id in world.featuredVerbs)
      if (verbById(id) case final v?) '${v.emoji}  ${v.label}',
  ];

  return [
    DayBeat(
      kind: DayBeatKind.open,
      label: 'Week ${world.week}',
      big: world.name,
      sub: world.tagline,
    ),
    DayBeat(
      kind: DayBeatKind.question,
      label: 'The question of this world',
      big: '“${world.question}”',
    ),
    if (verbLines.isNotEmpty)
      DayBeat(
        kind: DayBeatKind.verbs,
        label: 'This week’s verbs',
        lines: verbLines,
      ),
    if (rules.isNotEmpty)
      DayBeat(
        kind: DayBeatKind.rule,
        label: 'The rule of this world',
        big: rules.first.text,
      ),
    for (final v in world.videos)
      DayBeat(
        kind: DayBeatKind.watch,
        label: 'Watch · ${v.minutes} min',
        big: v.title,
        sub: '→ ${v.after}',
      ),
    if (thinking != null) ...[
      DayBeat(
        kind: DayBeatKind.play,
        label: 'Play it · ${thinking.concept}',
        big: thinking.play,
      ),
      DayBeat(
        kind: DayBeatKind.name,
        label: 'Name it',
        big: thinking.concept,
        sub: thinking.meaning,
      ),
      if (thinking.bridge.isNotEmpty)
        DayBeat(
          kind: DayBeatKind.bridge,
          label: 'Where else',
          lines: thinking.bridge,
        ),
      DayBeat(
        kind: DayBeatKind.ask,
        label: 'The question with no answer',
        big: '“${thinking.question}”',
        sub: 'Put it on the Wall',
      ),
    ],
    if (world.activities.isNotEmpty)
      DayBeat(
        kind: DayBeatKind.activity,
        label: 'Now go do it',
        lines: [
          for (final a in world.activities.take(6)) a.split(':').first.trim(),
        ],
      ),
    const DayBeat(
      kind: DayBeatKind.close,
      label: 'Closing',
      big: 'Who were you today?',
      sub: 'Reveal each name',
    ),
  ];
}

/// The story arc of ANY single activity, as a castable PROMPT (docs/VISION.md
/// "with present/cast… like a prompt"). The teacher's own activity, run through
/// play → name → bridge → question: each beat is a full-screen cue the room
/// sees and a move the teacher makes. The app prompts; the room is the stage.
List<DayBeat> buildActivityArc(String activity) {
  final a = activity.trim().isEmpty ? 'Your activity' : activity.trim();
  return [
    DayBeat(
      kind: DayBeatKind.play,
      label: 'Play it · 5 minutes',
      big: a,
      sub: 'Let it be noisy. One instruction, then go.',
    ),
    const DayBeat(
      kind: DayBeatKind.name,
      label: 'Name it',
      big: 'What ONE word does this secretly teach?',
      sub: 'Say it three times — whisper it, say it, shout it.',
    ),
    const DayBeat(
      kind: DayBeatKind.bridge,
      label: 'Bridge it · where else?',
      lines: [
        'Where else in THIS ROOM does this happen?',
        'Where else in YOUR LIFE?',
        'Where else in the WHOLE WORLD?',
      ],
    ),
    const DayBeat(
      kind: DayBeatKind.ask,
      label: 'The question',
      big: 'Now ask the one with no answer.',
      sub: 'Put it on the Wall. Walk away. Let it hang.',
    ),
    const DayBeat(
      kind: DayBeatKind.close,
      label: 'Closing',
      big: 'Who were you in this?',
      sub: 'Reveal each name.',
    ),
  ];
}
