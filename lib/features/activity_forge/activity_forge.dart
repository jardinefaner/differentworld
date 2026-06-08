import 'package:differentworld/features/action_words/verbs.dart';
import 'package:flutter/foundation.dart';

/// The **activity forge** (docs/VISION.md, the user's #3 novelty: "a library
/// runs out, a formula doesn't"). An activity isn't a whole pre-written
/// experience pulled from a finite list — it's FOUR atomic parts recombined:
/// a VERB (the action), a NOUN (the thing), a CONSTRAINT (the twist that turns
/// noise into play), and a TIME (the box). Any verb + any noun + any
/// constraint + any time = a new activity. The verb is the anchor; its lens
/// shapes how it's done.
///
/// Pure + deterministic (no RNG — a seed walks an odometer through the
/// catalogs), so it's unit-testable and reproducible.

/// The THINGS — room-available, evocative, age-agnostic. Each is a noun PHRASE
/// (carries its own article) so it slots straight after a verb.
const kForgeNouns = <String>[
  'a tower of blocks',
  'a cup of water',
  'a paper airplane',
  'a leaf',
  'a shadow',
  'a sound',
  'your own name',
  'a rock',
  'a pattern',
  'a balloon',
  'a drawing',
  'a story',
  'a rhythm',
  'a bridge of cups',
  'a secret',
  'a feeling',
  'a question',
  'a beam of light',
  "a friend's idea",
  'a ball of string',
  'a paper boat',
  'a stack of books',
  'a handful of sand',
  'a song nobody has heard',
  'a map of the room',
  'a chain of dominoes',
];

/// The TWISTS — the constraint is what turns an action into a game. Each is a
/// phrase that reads after the noun ("...without talking", "...as slowly as
/// possible").
const kForgeConstraints = <String>[
  'with your eyes closed',
  'without talking',
  'as slowly as you possibly can',
  'as quietly as a whisper',
  'with a partner, no words',
  'using only one hand',
  'without letting it touch the ground',
  'backwards',
  'without looking down',
  'in slow motion',
  'with your non-writing hand',
  'while balancing on one foot',
  'passing it person to person',
  'in complete silence',
  'in three big moves, no more',
  'so gently it never makes a sound',
  'while everyone watches',
  'before the timer runs out',
];

/// The BOXES — minutes. Short enough to stay play, varied enough to matter.
const kForgeTimes = <int>[1, 2, 5, 10];

/// The room's actual things, by curriculum world (docs/VISION.md "context-
/// bound"). When a world is live, the forge can draw its nouns from THIS
/// week's theme instead of the general set — so Water week forges with water.
/// Keyed by the curriculum world id.
const kWorldNouns = <String, List<String>>{
  'me': [
    'your own name',
    'your shadow',
    'your heartbeat',
    'a mirror',
    'your voice',
    'a self-portrait',
    'your handprint',
    'your fingerprint',
  ],
  'stories': [
    'a story',
    'a character',
    'a beginning',
    'a surprise ending',
    'a hero',
    'a once-upon-a-time',
    'a plot twist',
    'a secret',
  ],
  'nature': [
    'a leaf',
    'a rock',
    'a seed',
    'an ant',
    'a stick',
    'a shadow',
    'a feather',
    'a handful of dirt',
  ],
  'water': [
    'a cup of water',
    'a single drop',
    'a wave',
    'a paper boat',
    'an ice cube',
    'a puddle',
    'a river of string',
    'a sponge',
  ],
  'music': [
    'a rhythm',
    'a clap',
    'a hum',
    'a beat',
    'a silence',
    'a drum',
    'a song nobody has heard',
    'an echo',
  ],
  'space': [
    'a star',
    'the moon',
    'a beam of light',
    'a planet of clay',
    'a rocket of blocks',
    'a constellation',
    'the dark',
    'a shadow',
  ],
  'dreams': [
    'a dream',
    'a door',
    'a cloud',
    'a wish',
    'an impossible thing',
    'the flying you',
    'a color',
    'a what-if',
  ],
  'time': [
    'a clock',
    'a slow breath',
    'a fast run',
    'a pause',
    'a countdown',
    'a memory',
    'a single moment',
    'a tomorrow',
  ],
  'feelings': [
    'a feeling',
    'the color of a mood',
    'a calm breath',
    'a worry',
    'a joy',
    'a storm',
    'a sunny face',
    'a heavy thing',
  ],
  'us': [
    'a friend',
    "a friend's idea",
    'a circle',
    'a handshake',
    'a shared story',
    'a web of string',
    'a team',
    'a promise',
  ],
};

/// One forged activity: the four parts + a composed one-line instruction and
/// the verb that anchors it.
@immutable
class ForgedActivity {
  const ForgedActivity({
    required this.verb,
    required this.noun,
    required this.constraint,
    required this.minutes,
  });

  final Verb verb;
  final String noun;
  final String constraint;
  final int minutes;

  /// "Carry a cup of water without talking."
  String get instruction {
    final v = verb.label;
    return '$v $noun $constraint.';
  }

  /// How many distinct activities the four catalogs can make.
  static int get space =>
      kVerbs.length *
      kForgeNouns.length *
      kForgeConstraints.length *
      kForgeTimes.length;
}

/// Forge an activity from a [seed]. The seed is an odometer: the noun turns
/// fastest (so consecutive rolls always feel different), then the constraint,
/// then the time. The verb is independent — pass [verbId] to LOCK it to what
/// you're teaching; leave it null to let the seed pick one too.
ForgedActivity forgeActivity(int seed, {String? verbId, List<String>? nouns}) {
  final s = seed.abs();
  final nounList = (nouns == null || nouns.isEmpty) ? kForgeNouns : nouns;
  final nounLen = nounList.length;
  final consLen = kForgeConstraints.length;
  final timeLen = kForgeTimes.length;

  final verb =
      (verbId != null ? verbById(verbId) : null) ?? kVerbs[s % kVerbs.length];
  final noun = nounList[s % nounLen];
  final constraint = kForgeConstraints[(s ~/ nounLen) % consLen];
  final minutes = kForgeTimes[(s ~/ (nounLen * consLen)) % timeLen];

  return ForgedActivity(
    verb: verb,
    noun: noun,
    constraint: constraint,
    minutes: minutes,
  );
}
