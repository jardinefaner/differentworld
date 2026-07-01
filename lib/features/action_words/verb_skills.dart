import 'package:flutter/foundation.dart';

/// The SKILLS underneath the 12 verbs (docs/VISION.md 2026-06-30 "every verb has
/// skills underneath it"). The verb is WHAT you do; the skill is HOW WELL — and
/// it's a NUMBER that goes up with practice. Five skills per verb, 60 total.
///
/// Every skill obeys the same law: one word · zero materials · measurable ·
/// improves with practice · maps to one verb · practiceable right now. The
/// growth in the number IS the character development — measured, not described.
///
/// This is the pure catalog (the bedrock, like `verbs.dart`). The measurements
/// table + the record-a-rep flow + the progression view are the next slices.
///
/// NB: a separate `skills.dart` holds the staff `TeachSkill` ("teach one skill a
/// day") — unrelated; this file is the kid-facing verb skills.

/// How a skill is scored — drives how the staffer records it + what the kid sees.
enum SkillMeasureKind {
  /// A held / sustained duration, in seconds (Endure, Silence, Still, Stare…).
  /// Recorded with a stopwatch.
  seconds,

  /// A tally in ONE attempt — sounds heard, uses invented, blocks high, words
  /// repeated (Count, Diverge, Stack, Repeat…). Recorded with a +/- counter.
  count,

  /// A recurring tally across a day / week — times you noticed, included,
  /// filled a gap (Deliver, Include, Notice, Yield…). One tap each time it
  /// happens.
  frequency,

  /// A 1–5 judgement of quality / accuracy / smoothness, for skills with no
  /// clean number (Locate, Plan, Pace, Diagnose, Receive…).
  rating;

  /// The unit label shown next to the number.
  String get unit => switch (this) {
    SkillMeasureKind.seconds => 'sec',
    SkillMeasureKind.count => '',
    SkillMeasureKind.frequency => '/day',
    SkillMeasureKind.rating => '/ 5',
  };
}

/// One measurable skill under a verb.
@immutable
class VerbSkill {
  const VerbSkill({
    required this.verbId,
    required this.name,
    required this.measure,
    required this.how,
    required this.week1,
    required this.week10,
    this.higherIsBetter = true,
  });

  /// The verb this skill lives under — a `Verb.id` from verbs.dart.
  final String verbId;

  /// The skill's name. Always ONE word ('Lift', 'Count', 'Still').
  final String name;

  /// How the score is taken + recorded.
  final SkillMeasureKind measure;

  /// True when a bigger number is the win (most skills). FALSE for the speed
  /// skills where FASTER — a smaller number of seconds — is better (Start,
  /// Volunteer, Invent, Recover, Read, Transition, Redirect).
  final bool higherIsBetter;

  /// The one-line "how you practice it", kid/staff facing.
  final String how;

  /// Where most kids start (the week-1 anchor).
  final String week1;

  /// What mastery looks like (the week-10 anchor).
  final String week10;

  /// Stable id for storage: `<verbId>.<name lowercased>` (e.g. 'carry.lift').
  String get id => '$verbId.${name.toLowerCase()}';
}

/// The canonical 60 — five skills per verb, in verb display order. The set is
/// stable; ids are stored in measurements, so renaming a skill is a migration.
const List<VerbSkill> kVerbSkills = [
  // ── CARRY 📦 ───────────────────────────────────────────────────────────────
  VerbSkill(
    verbId: 'carry',
    name: 'Lift',
    measure: SkillMeasureKind.count,
    how: 'Pick up something heavy. How heavy can you go safely?',
    week1: 'a book',
    week10: 'a chair',
  ),
  VerbSkill(
    verbId: 'carry',
    name: 'Steady',
    measure: SkillMeasureKind.rating,
    how: 'Carry a full cup across the room. How little spills?',
    week1: 'half spills',
    week10: 'nothing spills',
  ),
  VerbSkill(
    verbId: 'carry',
    name: 'Gentle',
    measure: SkillMeasureKind.rating,
    how: 'Put something down without a sound. How little force do you choose?',
    week1: 'it clunks',
    week10: 'silent',
  ),
  VerbSkill(
    verbId: 'carry',
    name: 'Deliver',
    measure: SkillMeasureKind.frequency,
    how: 'Bring someone what they need before they ask.',
    week1: 'only when told',
    week10: 'notices + goes unprompted',
  ),
  VerbSkill(
    verbId: 'carry',
    name: 'Endure',
    measure: SkillMeasureKind.seconds,
    how: 'Hold something heavy as long as you can — no moving, just holding.',
    week1: '15 seconds',
    week10: '90 seconds',
  ),

  // ── LISTEN 👂 ────────────────────────────────────────────────────────────────
  VerbSkill(
    verbId: 'listen',
    name: 'Count',
    measure: SkillMeasureKind.count,
    how: 'Eyes closed — how many sounds in 30 seconds?',
    week1: '3 sounds',
    week10: '12 sounds',
  ),
  VerbSkill(
    verbId: 'listen',
    name: 'Locate',
    measure: SkillMeasureKind.rating,
    how: 'Eyes closed — point to where a sound came from.',
    week1: 'general direction',
    week10: 'the exact spot',
  ),
  VerbSkill(
    verbId: 'listen',
    name: 'Separate',
    measure: SkillMeasureKind.seconds,
    how: 'Follow ONE sound in a noisy room. How long before attention drifts?',
    week1: 'drifts fast',
    week10: 'holds it long',
  ),
  VerbSkill(
    verbId: 'listen',
    name: 'Remember',
    measure: SkillMeasureKind.count,
    how: 'Someone claps a rhythm. Wait 5 seconds, then clap it back.',
    week1: '3 claps',
    week10: '7+ with pauses',
  ),
  VerbSkill(
    verbId: 'listen',
    name: 'Silence',
    measure: SkillMeasureKind.seconds,
    how: 'Sit in complete silence — no shifting, no tapping. Time it.',
    week1: '8 seconds',
    week10: 'a minute',
  ),

  // ── PLAY 🎉 ───────────────────────────────────────────────────────────────────
  VerbSkill(
    verbId: 'play',
    name: 'Invent',
    measure: SkillMeasureKind.seconds,
    higherIsBetter: false,
    how: 'Make up a game with one rule, on the spot. How fast?',
    week1: '2 minutes',
    week10: 'instant',
  ),
  VerbSkill(
    verbId: 'play',
    name: 'Shift',
    measure: SkillMeasureKind.count,
    how: 'Someone changes the rules mid-game. How many changes can you absorb?',
    week1: 'freezes',
    week10: 'shifts every time',
  ),
  VerbSkill(
    verbId: 'play',
    name: 'Recover',
    measure: SkillMeasureKind.seconds,
    higherIsBetter: false,
    how: "You lost. How fast from 'I lost' to 'let's play again'?",
    week1: 'sulks 5 min',
    week10: 'no pause',
  ),
  VerbSkill(
    verbId: 'play',
    name: 'Include',
    measure: SkillMeasureKind.frequency,
    how: "Say 'want to play?' to someone watching — without being told.",
    week1: 'never',
    week10: 'often, unprompted',
  ),
  VerbSkill(
    verbId: 'play',
    name: 'Laugh',
    measure: SkillMeasureKind.frequency,
    how: 'Make someone laugh on purpose — surprising or silly, never mean.',
    week1: 'rarely',
    week10: 'many a day',
  ),

  // ── SPARK ✨ ─────────────────────────────────────────────────────────────────
  VerbSkill(
    verbId: 'spark',
    name: 'Start',
    measure: SkillMeasureKind.seconds,
    higherIsBetter: false,
    how: 'Blank page — first mark within 5 seconds. Any mark.',
    week1: 'stares',
    week10: 'marks instantly',
  ),
  VerbSkill(
    verbId: 'spark',
    name: 'Volunteer',
    measure: SkillMeasureKind.seconds,
    higherIsBetter: false,
    how: "'Who wants to go first?' — how fast does your hand go up?",
    week1: 'never',
    week10: 'first hand',
  ),
  VerbSkill(
    verbId: 'spark',
    name: 'Diverge',
    measure: SkillMeasureKind.count,
    how: "'How many uses for a cup?' — count in 60 seconds.",
    week1: '3 uses',
    week10: '11 uses',
  ),
  VerbSkill(
    verbId: 'spark',
    name: 'Connect',
    measure: SkillMeasureKind.count,
    how: 'Two random objects — how are they related? Count in 30 seconds.',
    week1: '1–2',
    week10: '4+ fast',
  ),
  VerbSkill(
    verbId: 'spark',
    name: 'Risk',
    measure: SkillMeasureKind.frequency,
    how: "Say an answer you're unsure of — out loud, no hedging.",
    week1: 'zero',
    week10: '3–4 a day',
  ),

  // ── FLOW 🌊 ───────────────────────────────────────────────────────────────────
  VerbSkill(
    verbId: 'flow',
    name: 'Read',
    measure: SkillMeasureKind.seconds,
    higherIsBetter: false,
    how: 'Walk into a room — how fast do you read its energy / who needs help?',
    week1: "doesn't notice",
    week10: 'reads in 3 seconds',
  ),
  VerbSkill(
    verbId: 'flow',
    name: 'Transition',
    measure: SkillMeasureKind.seconds,
    higherIsBetter: false,
    how: "Move to the next activity — seconds from 'circle up' to in the circle.",
    week1: '45 seconds',
    week10: '5 seconds',
  ),
  VerbSkill(
    verbId: 'flow',
    name: 'Fill',
    measure: SkillMeasureKind.frequency,
    how: 'See a gap, fill it. How many gaps a day without being asked?',
    week1: 'none',
    week10: 'many',
  ),
  VerbSkill(
    verbId: 'flow',
    name: 'Pace',
    measure: SkillMeasureKind.rating,
    how: "Walk at someone else's speed, not yours. Match their rhythm.",
    week1: 'own pace',
    week10: 'matches anyone',
  ),
  VerbSkill(
    verbId: 'flow',
    name: 'Redirect',
    measure: SkillMeasureKind.seconds,
    higherIsBetter: false,
    how: 'A plan breaks — how fast can you pivot to something else?',
    week1: 'freezes',
    week10: 'instant pivot',
  ),

  // ── BUILD 🧱 ──────────────────────────────────────────────────────────────────
  VerbSkill(
    verbId: 'build',
    name: 'Stack',
    measure: SkillMeasureKind.count,
    how: 'How high before it falls? Blocks, cups, books.',
    week1: 'a few high',
    week10: 'tall + knows why it fell',
  ),
  VerbSkill(
    verbId: 'build',
    name: 'Repair',
    measure: SkillMeasureKind.rating,
    how: 'Something broke — can you FIX it, not replace it?',
    week1: 'discards it',
    week10: 'repairs it',
  ),
  VerbSkill(
    verbId: 'build',
    name: 'Plan',
    measure: SkillMeasureKind.rating,
    how: "Describe what you'll build, then build it. How close to the plan?",
    week1: 'no match',
    week10: 'close',
  ),
  VerbSkill(
    verbId: 'build',
    name: 'Iterate',
    measure: SkillMeasureKind.count,
    how: 'Build, find what is wrong, fix, look again. How many cycles?',
    week1: '1 cycle',
    week10: '5 cycles',
  ),
  VerbSkill(
    verbId: 'build',
    name: 'Collaborate',
    measure: SkillMeasureKind.rating,
    how: 'Build with a partner without talking — read their intention.',
    week1: "can't",
    week10: 'silent + coherent',
  ),

  // ── WATCH 👀 ──────────────────────────────────────────────────────────────────
  VerbSkill(
    verbId: 'watch',
    name: 'Stare',
    measure: SkillMeasureKind.seconds,
    how: "One object, don't look away. Time it — new details emerge.",
    week1: 'a few seconds',
    week10: 'a long hold',
  ),
  VerbSkill(
    verbId: 'watch',
    name: 'Recall',
    measure: SkillMeasureKind.count,
    how: 'Look at a scene 10 seconds, close your eyes — how many details?',
    week1: 'a few',
    week10: 'many',
  ),
  VerbSkill(
    verbId: 'watch',
    name: 'Track',
    measure: SkillMeasureKind.seconds,
    how: 'Follow something moving with only your eyes — how long without losing it?',
    week1: 'loses it fast',
    week10: 'a long track',
  ),
  VerbSkill(
    verbId: 'watch',
    name: 'Differ',
    measure: SkillMeasureKind.count,
    how: 'Two things side by side — how many differences in 30 seconds?',
    week1: '1–2',
    week10: 'many',
  ),
  VerbSkill(
    verbId: 'watch',
    name: 'Predict',
    measure: SkillMeasureKind.rating,
    how: 'Watch 30 seconds — what happens next? How accurate?',
    week1: 'guesses',
    week10: 'reads the pattern',
  ),

  // ── WAIT ⏳ ───────────────────────────────────────────────────────────────────
  VerbSkill(
    verbId: 'wait',
    name: 'Still',
    measure: SkillMeasureKind.seconds,
    how: 'Hold completely motionless. Time it — doing nothing is the measure.',
    week1: '12 seconds',
    week10: '2 minutes',
  ),
  VerbSkill(
    verbId: 'wait',
    name: 'Pause',
    measure: SkillMeasureKind.frequency,
    how: "A question comes — don't answer for 5 seconds. Hold the silence.",
    week1: 'blurts',
    week10: 'pauses often',
  ),
  VerbSkill(
    verbId: 'wait',
    name: 'Tolerate',
    measure: SkillMeasureKind.seconds,
    how: "Something's uncomfortable — sit with it, don't fix it. How long?",
    week1: 'reacts fast',
    week10: 'sits with it',
  ),
  VerbSkill(
    verbId: 'wait',
    name: 'Yield',
    measure: SkillMeasureKind.frequency,
    how: 'Let someone go first — chosen, not forced.',
    week1: 'never',
    week10: 'often',
  ),
  VerbSkill(
    verbId: 'wait',
    name: 'Trust',
    measure: SkillMeasureKind.rating,
    how: "Plant a seed — don't dig it up. Trust the invisible process.",
    week1: 'digs it up',
    week10: 'waits + believes',
  ),

  // ── SOLVE 🧩 ──────────────────────────────────────────────────────────────────
  VerbSkill(
    verbId: 'solve',
    name: 'Try',
    measure: SkillMeasureKind.count,
    how: 'Attempt it before asking how. How many tries before you ask for help?',
    week1: 'asks first',
    week10: 'tries 3 times',
  ),
  VerbSkill(
    verbId: 'solve',
    name: 'Diagnose',
    measure: SkillMeasureKind.rating,
    how: "Why isn't it working? How SPECIFIC is your answer?",
    week1: "'it's broken'",
    week10: 'names the exact cause',
  ),
  VerbSkill(
    verbId: 'solve',
    name: 'Simplify',
    measure: SkillMeasureKind.count,
    how: 'Break a big problem into parts. How many steps before starting?',
    week1: 'attacks the whole',
    week10: '3 steps, does one',
  ),
  VerbSkill(
    verbId: 'solve',
    name: 'Transfer',
    measure: SkillMeasureKind.rating,
    how: "Yesterday's solution fits today's different problem — can you see it?",
    week1: "can't",
    week10: 'transfers across',
  ),
  VerbSkill(
    verbId: 'solve',
    name: 'Abandon',
    measure: SkillMeasureKind.rating,
    how: 'Not working for 5 min — can you STOP and try a different approach?',
    week1: 'repeats harder',
    week10: 'resets + restarts',
  ),

  // ── HELP 💛 ───────────────────────────────────────────────────────────────────
  VerbSkill(
    verbId: 'help',
    name: 'Notice',
    measure: SkillMeasureKind.frequency,
    how: 'See someone needs help before they ask. How many times a day?',
    week1: 'misses it',
    week10: 'scans for people',
  ),
  VerbSkill(
    verbId: 'help',
    name: 'Ask',
    measure: SkillMeasureKind.rating,
    how: "'Do you need help?' — offered genuinely, giving them the choice.",
    week1: 'takes over',
    week10: 'offers, lets them choose',
  ),
  VerbSkill(
    verbId: 'help',
    name: 'Hold',
    measure: SkillMeasureKind.seconds,
    how: "Someone's upset — don't fix it, just sit there. 'I'm here.' How long?",
    week1: 'rushes to fix',
    week10: 'holds the pain',
  ),
  VerbSkill(
    verbId: 'help',
    name: 'Teach',
    measure: SkillMeasureKind.rating,
    how: 'Show someone how to do it themselves — did they do it alone after?',
    week1: 'does it for them',
    week10: 'they do it alone',
  ),
  VerbSkill(
    verbId: 'help',
    name: 'Withdraw',
    measure: SkillMeasureKind.rating,
    how: 'They can do it now — can you step back without being asked?',
    week1: 'hovers',
    week10: 'steps back on time',
  ),

  // ── ECHO 🔁 ───────────────────────────────────────────────────────────────────
  VerbSkill(
    verbId: 'echo',
    name: 'Repeat',
    measure: SkillMeasureKind.count,
    how: 'Say a sentence back word for word — how many words accurately?',
    week1: '3 words',
    week10: '10 words',
  ),
  VerbSkill(
    verbId: 'echo',
    name: 'Transform',
    measure: SkillMeasureKind.rating,
    how: 'Say it back differently — same meaning, new words.',
    week1: 'reorders words',
    week10: 'new language, same feeling',
  ),
  VerbSkill(
    verbId: 'echo',
    name: 'Mirror',
    measure: SkillMeasureKind.rating,
    how: 'Copy a movement exactly — speed, direction, energy all matched.',
    week1: 'approximate',
    week10: 'a precise mirror',
  ),
  VerbSkill(
    verbId: 'echo',
    name: 'Interpret',
    measure: SkillMeasureKind.rating,
    how: 'Describe what you SEE in their drawing — not what you think they meant.',
    week1: 'projects',
    week10: 'describes what is there',
  ),
  VerbSkill(
    verbId: 'echo',
    name: 'Validate',
    measure: SkillMeasureKind.rating,
    how: "'What I hear you saying is…' then 'Is that right?'",
    week1: 'performs',
    week10: 'paraphrases + checks',
  ),

  // ── SHINE 💡 ──────────────────────────────────────────────────────────────────
  VerbSkill(
    verbId: 'shine',
    name: 'Stand',
    measure: SkillMeasureKind.seconds,
    how: 'Stand in front of people — how long without fidgeting or sitting?',
    week1: '3 seconds',
    week10: '30 seconds',
  ),
  VerbSkill(
    verbId: 'shine',
    name: 'Name',
    measure: SkillMeasureKind.rating,
    how: 'Say your name out loud, in a room — how clear + strong?',
    week1: 'a whisper',
    week10: 'clear, like it matters',
  ),
  VerbSkill(
    verbId: 'shine',
    name: 'Show',
    measure: SkillMeasureKind.seconds,
    how: "Hold up something you made — don't explain, don't apologize. How long?",
    week1: 'hides it fast',
    week10: 'holds + lets it be seen',
  ),
  VerbSkill(
    verbId: 'shine',
    name: 'Claim',
    measure: SkillMeasureKind.rating,
    how: 'Say something true about yourself — no hedging.',
    week1: "'I guess I'm sort of…'",
    week10: "'I'm a good drawer.' Period.",
  ),
  VerbSkill(
    verbId: 'shine',
    name: 'Receive',
    measure: SkillMeasureKind.frequency,
    how: "Someone compliments you — say 'thank you,' don't deflect.",
    week1: "'no I'm not'",
    week10: "'thank you' + holds it",
  ),
];

/// The five skills under a verb, in catalog order. Empty for an unknown id.
List<VerbSkill> skillsForVerb(String verbId) =>
    [for (final s in kVerbSkills) if (s.verbId == verbId) s];

/// Fast id → VerbSkill lookup (id is `<verbId>.<name lowercased>`).
final Map<String, VerbSkill> _byId = {for (final s in kVerbSkills) s.id: s};

VerbSkill? verbSkillById(String id) => _byId[id];

/// How many skills live under every verb.
const int kSkillsPerVerb = 5;
