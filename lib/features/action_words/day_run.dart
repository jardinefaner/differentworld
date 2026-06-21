import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/thinking_games.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/world_rules.dart';
// material.dart for Color (the per-beat tint) + @immutable. A pure-data file,
// but Color comes from the painting/material layer, not foundation.
import 'package:flutter/material.dart';

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
  photo, // a keepsake image — a child's work sample / moment (growth arc)
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
    this.suggestedSeconds = 0,
    this.emoji = '',
    this.guidance = '',
    this.imageUrl = '',
    this.color,
  });

  final DayBeatKind kind;

  /// Per-beat tint — the world's colour for a journey beat, so a tappable
  /// deck-overview grid can tile each beat in its world's hue. Null → the
  /// surface falls back to the deck accent (a one-world day run leaves it
  /// null and uses the world accent uniformly). Content-driven, NOT a theme
  /// colour: when used as a FILL behind text, pick the foreground via
  /// `AppColors.onAccent`.
  final Color? color;

  /// For [DayBeatKind.photo] — a (signed) image URL to render full-bleed.
  /// The growth arc fills this from the child's work-sample / observation
  /// attachments so the story shows what they MADE, not just stats.
  final String imageUrl;

  /// The STAFF's "your move" cue for this beat — what to say, what to watch
  /// for, when to advance. Shown ONLY on the phone (the conductor's score),
  /// never on the big screen. Empty → [beatGuidance] supplies a templated
  /// default for the [kind]; authored per-beat overrides can fill this later.
  final String guidance;

  /// Small caption above the headline ("WEEK 4 · WATCH · 3 MIN").
  final String label;

  /// Per-beat hero glyph for `open` beats — overrides the presenter's single
  /// emoji so a multi-world tour shows EACH world's glyph (the journey cast),
  /// not one global one. Empty → fall back to the presenter's emoji.
  final String emoji;

  /// The headline — the thing read from across the room.
  final String big;

  /// Optional supporting line under the headline.
  final String sub;

  /// For list beats (verbs, the bridge steps, the activity menu).
  final List<String> lines;

  /// A sensible timer length for this beat, in seconds (0 = none). The
  /// present surface offers it as the lead option when the teacher sets a
  /// timer — but it's only a *suggestion*: they can pick any duration and
  /// the surface remembers their customs. The Watch beat suggests the
  /// video's length; the Big-Thinking play beat the 5-minute play.
  final int suggestedSeconds;
}

/// The staff cue for a beat — its authored [DayBeat.guidance] if set, else a
/// templated default by [DayBeatKind]. Pure + testable. Shown phone-side only
/// (the conductor's score); never cast to the room screen.
String beatGuidance(DayBeat beat) {
  if (beat.guidance.trim().isNotEmpty) return beat.guidance.trim();
  return switch (beat.kind) {
    DayBeatKind.open =>
      "Set the scene — say the world's name big. Move on when eyes are up.",
    DayBeatKind.question =>
      "Ask it out loud. Take 2–3 answers; don't resolve them. Move when the "
          'room is curious.',
    DayBeatKind.verbs =>
      "Name today's words. Have each kid claim one. Move when everyone has.",
    DayBeatKind.rule =>
      'Say the rule, then ask "why might that matter?" Move when they get it.',
    DayBeatKind.watch =>
      'Play the clip — watch THEM, not the screen. Move when it ends.',
    DayBeatKind.play =>
      'Let them play it, hands-on. Watch for the first kid who finds the '
          'pattern, then move to Name.',
    DayBeatKind.name =>
      'Name what they did together. Spell the key word out loud. Move when '
          'they can say it back.',
    DayBeatKind.bridge =>
      'Ask "where else does this happen?" Take a few. Move when they have '
          'stretched it.',
    DayBeatKind.ask =>
      "Pose the Wall question — don't answer it. Let it sit, then send them "
          'to it.',
    DayBeatKind.activity =>
      "Send them to the activity, set a timer, circulate — don't hover.",
    // A keepsake photo beat (growth arc) carries no staff cue — it's a
    // moment to sit with, not a move to make.
    DayBeatKind.photo => '',
    DayBeatKind.close =>
      'Gather back. One word each on what they made. Hand off to the reveal.',
  };
}

/// A short name for a beat kind — labels the "Next — {…}" control so the staff
/// sees what's coming without reading ahead.
String beatKindShortLabel(DayBeatKind kind) => switch (kind) {
  DayBeatKind.open => 'Open',
  DayBeatKind.question => 'Question',
  DayBeatKind.verbs => 'Words',
  DayBeatKind.rule => 'Rule',
  DayBeatKind.watch => 'Watch',
  DayBeatKind.play => 'Play',
  DayBeatKind.name => 'Name it',
  DayBeatKind.bridge => 'Bridge',
  DayBeatKind.ask => 'Ask',
  DayBeatKind.activity => 'Activity',
  DayBeatKind.photo => 'Photo',
  DayBeatKind.close => 'Close',
};

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
  int playSeconds = 5 * 60,
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
        suggestedSeconds: v.minutes * 60,
      ),
    if (thinking != null) ...[
      DayBeat(
        kind: DayBeatKind.play,
        label: 'Play it · ${thinking.concept}',
        big: thinking.play,
        suggestedSeconds: playSeconds,
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
List<DayBeat> buildActivityArc(String activity, {int playSeconds = 5 * 60}) {
  final a = activity.trim().isEmpty ? 'Your activity' : activity.trim();
  return [
    DayBeat(
      kind: DayBeatKind.play,
      label: 'Play it · ${playSeconds ~/ 60} minutes',
      big: a,
      sub: 'Let it be noisy. One instruction, then go.',
      suggestedSeconds: playSeconds,
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

/// The whole-summer cast — ONE walkthrough of the journey, world by world (the
/// user's "one cast that walks the whole experience"). Built from the live
/// curriculum so it always matches the program: an orientation tour for staff
/// or families, or a season-opener for the room. Each world is its hero + its
/// question; the arc is framed by an opening and a closing.
List<DayBeat> buildJourneyTour(List<CurriculumWorld> worlds) {
  final sorted = [...worlds]..sort((a, b) => a.week.compareTo(b.week));
  return [
    const DayBeat(
      kind: DayBeatKind.open,
      label: 'One summer',
      big: 'Different World',
      sub: 'Pick three verbs. Live them. Discover who you became.',
    ),
    for (final w in sorted) ...[
      DayBeat(
        kind: DayBeatKind.open,
        label: 'Week ${w.week}',
        big: w.name,
        sub: w.tagline,
        emoji: w.emoji,
        color: w.color,
      ),
      DayBeat(
        kind: DayBeatKind.question,
        label: 'The question of this world',
        big: '“${w.question}”',
        color: w.color,
      ),
    ],
    const DayBeat(
      kind: DayBeatKind.close,
      label: 'And then',
      big: 'Who will you become?',
      sub: 'The room fills. You go deeper. The game continues.',
    ),
  ];
}
