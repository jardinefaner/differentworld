import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/worlds.dart';
import 'package:flutter/foundation.dart';

/// A sense a "become it" beat engages. The reveal is "you ARE this world
/// today"; the senses are HOW you become it — move like it, sound like it,
/// feel it. This is how the culture (a world) becomes an activity, the
/// sensory way (docs/ACTION_WORDS.md).
enum Sense {
  move('👋', 'Move'),
  sound('👂', 'Sound'),
  touch('✋', 'Touch'),
  look('👀', 'Look'),
  smell('👃', 'Smell')
  ;

  const Sense(this.emoji, this.label);
  final String emoji;
  final String label;
}

/// One sensory cue for becoming a world — "glide and leap" (move).
@immutable
class SenseBeat {
  const SenseBeat(this.sense, this.prompt);
  final Sense sense;
  final String prompt;
}

/// The multi-sensory "become it" for each catalog world. Short embodiment
/// cues a 4–7-year-old can DO. Programs extend these (their own culture).
const Map<String, List<SenseBeat>> kWorldBecome = {
  'ant': [
    SenseBeat(Sense.move, 'March in a line and carry a heavy crumb'),
    SenseBeat(Sense.touch, 'Lift something heavier than you expect'),
  ],
  'dolphin': [
    SenseBeat(Sense.move, 'Glide and leap through the air'),
    SenseBeat(Sense.sound, 'Click and whistle to a friend'),
  ],
  'eagle': [
    SenseBeat(Sense.move, 'Spread wide wings and soar slow'),
    SenseBeat(Sense.look, 'Spot one tiny thing far away'),
  ],
  'owl': [
    SenseBeat(Sense.sound, 'Hoot soft and low'),
    SenseBeat(Sense.look, 'Turn your head all the way around'),
    SenseBeat(Sense.move, 'Sit perfectly, perfectly still'),
  ],
  'bee': [
    SenseBeat(Sense.move, 'Buzz busy and build a little cell'),
    SenseBeat(Sense.sound, 'Bzzzzz as you work'),
  ],
  'water': [
    SenseBeat(Sense.move, 'Flow and ripple across the floor'),
    SenseBeat(Sense.touch, 'Be cool and smooth and calm'),
  ],
  'fire': [
    SenseBeat(Sense.move, 'Flicker and dance, big then small'),
    SenseBeat(Sense.look, 'Glow your brightest'),
  ],
  'star': [
    SenseBeat(Sense.move, 'Twinkle on your tiptoes'),
    SenseBeat(Sense.move, 'Then shine steady and quiet'),
  ],
  'beaver': [
    SenseBeat(Sense.move, 'Carry sticks and build a dam'),
    SenseBeat(Sense.touch, 'Pat the mud down flat'),
  ],
  'turtle': [
    SenseBeat(Sense.move, 'Go slow and steady, no rush'),
    SenseBeat(Sense.touch, 'Tuck safe inside your shell'),
  ],
  'dog': [
    SenseBeat(Sense.move, 'Wag and bound to a friend'),
    SenseBeat(Sense.sound, 'A happy little bark'),
  ],
  'fox': [
    SenseBeat(Sense.move, 'Sneak quiet on soft paws'),
    SenseBeat(Sense.look, 'Watch with clever eyes'),
  ],
  'elephant': [
    SenseBeat(Sense.move, 'Stomp slow and swing your trunk'),
    SenseBeat(Sense.sound, 'A big trumpet call'),
  ],
  'wind': [
    SenseBeat(Sense.move, 'Swirl and rush around the room'),
    SenseBeat(Sense.sound, 'Whoooosh as you go'),
  ],
  'mountain': [
    SenseBeat(Sense.move, 'Stand tall and still and strong'),
    SenseBeat(Sense.touch, 'Be solid — try to be moved'),
  ],
};

/// The sensory "become it" for a resolved world. Catalog worlds use their
/// authored beats; an invented/fresh world (the class's own) gets a
/// generic embodiment from its three verbs — act out your words.
List<SenseBeat> becomeFor(WorldMatch match) {
  final world = match.world;
  if (world != null) {
    final beats = kWorldBecome[world.id];
    if (beats != null) return beats;
  }
  // Generic: become your three words with your body.
  return [
    for (final v in verbsByIds(match.picks.toList()))
      SenseBeat(Sense.move, 'Show us ${v.label.toLowerCase()} with your body'),
  ];
}
