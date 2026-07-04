import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';

/// Procedural content generators — the "many possibilities, always new"
/// engine, entirely IN-APP (no AI, no network). Each generator combines small
/// hand-authored pools into a huge space: a 4-slot template of ~15-item pools
/// is already 50,000+ distinct items; math (in math_game.dart) is literally
/// infinite. Add a few pool items → the space multiplies.
///
/// They plug in behind [ContentSource] via `ContentEngine`, so games never
/// change — `content.take(kind, n)` just returns fresh, varied items.
abstract class ContentGenerator {
  String get kind;

  /// The number of distinct items this generator can produce (the "X
  /// combinations" figure shown to teachers).
  int get space;

  /// Produce up to [n] DISTINCT items, skipping any whose `kind/fingerprint`
  /// is in [exclude] (recently seen). Pure given [rng].
  List<ContentItem> generate(
    int n,
    Random rng, {
    Set<String> exclude = const {},
  });
}

/// A product-of-slots generator: pick one entry from each [slots] pool, format
/// them into the item text. Space = product of the slot lengths.
class TemplateGenerator implements ContentGenerator {
  TemplateGenerator({
    required this.kind,
    required this.slots,
    required this.format,
    this.payloadKey = 'text',
  });

  @override
  final String kind;

  /// One pool per slot; an item draws one entry from each.
  final List<List<String>> slots;

  /// Combine the picked entries (one per slot) into the displayed string.
  final String Function(List<String> picks) format;

  final String payloadKey;

  @override
  int get space => slots.fold(1, (p, s) => p * s.length);

  @override
  List<ContentItem> generate(
    int n,
    Random rng, {
    Set<String> exclude = const {},
  }) {
    final out = <ContentItem>[];
    final used = <String>{...exclude};
    final cap = n * 60; // collision guard; the space dwarfs n
    var guard = 0;
    while (out.length < n && guard < cap) {
      guard++;
      final picks = [for (final s in slots) s[rng.nextInt(s.length)]];
      final fp = picks.join('|').toLowerCase();
      if (used.add('$kind/$fp')) {
        out.add(
          ContentItem(
            kind: kind,
            fingerprint: fp,
            payload: {payloadKey: format(picks)},
          ),
        );
      }
    }
    return out;
  }
}

/// Picks an unordered DISTINCT pair from one of several themed pools — a
/// meaningful "this or that" contrast (two foods, two superpowers, …), never
/// a nonsense cross-theme pair. Space = Σ C(poolSize, 2).
class PairGenerator implements ContentGenerator {
  PairGenerator({required this.kind, required this.themes});

  @override
  final String kind;

  /// Each theme is a pool of comparable options; a pair is two from one theme.
  final List<List<String>> themes;

  @override
  int get space =>
      themes.fold(0, (sum, t) => sum + (t.length * (t.length - 1)) ~/ 2);

  @override
  List<ContentItem> generate(
    int n,
    Random rng, {
    Set<String> exclude = const {},
  }) {
    final pools = themes.where((t) => t.length >= 2).toList();
    final out = <ContentItem>[];
    if (pools.isEmpty) return out;
    final used = <String>{...exclude};
    final cap = n * 60;
    var guard = 0;
    while (out.length < n && guard < cap) {
      guard++;
      final pool = pools[rng.nextInt(pools.length)];
      final i = rng.nextInt(pool.length);
      final j = rng.nextInt(pool.length);
      if (i == j) continue;
      final a = pool[i];
      final b = pool[j];
      // Unordered fingerprint so (a,b) == (b,a).
      final lo = a.toLowerCase().compareTo(b.toLowerCase()) <= 0 ? a : b;
      final hi = identical(lo, a) ? b : a;
      final fp = '${lo.toLowerCase()}|${hi.toLowerCase()}';
      if (used.add('$kind/$fp')) {
        out.add(
          ContentItem(
            kind: kind,
            fingerprint: fp,
            payload: {'a': a, 'b': b},
          ),
        );
      }
    }
    return out;
  }
}

// ── Pools ──────────────────────────────────────────────────────────────────
// Small, kid-safe, hand-authored. The combinatorics do the rest.

const _storyTimes = [
  'One morning,',
  'At recess,',
  'On a rainy Tuesday,',
  'Just before lunch,',
  'In the middle of the night,',
  'After the last bell,',
  'On the very first day of school,',
  'During the field trip,',
  'One foggy evening,',
  'Right after nap time,',
  'On a snowy afternoon,',
  'When nobody was looking,',
];

const _storySubjects = [
  'a curious kid',
  'the new student',
  'the class pet',
  'a tiny robot',
  'the substitute teacher',
  'a girl named Mira',
  'two best friends',
  'the quietest kid in class',
  'a talking backpack',
  'a lost puppy',
  'a brave little mouse',
  'the fastest runner in school',
  'a sleepy dragon',
  'a kid with a wild imagination',
  'an old wizard',
  'a robot named Bolt',
  'the school janitor',
  'a grandma with a secret',
];

const _storyEvents = [
  'woke up able to talk to animals',
  'found a tiny door at the back of the room',
  'got a backpack that was bigger on the inside',
  'noticed their shadow doing its own thing',
  'discovered a map hidden in a library book',
  'heard the oldest tree whisper a name',
  'found a treasure chest at recess',
  'could suddenly fly — but only for a minute',
  'realized the cafeteria food was a little bit magic',
  'got a letter with no return address',
  'found a key that did not fit any lock',
  'met a creature only they could see',
  'woke up tiny — the size of a thumb',
  'found a button that paused time',
  'got a pet that was not supposed to exist',
  'heard music coming from inside the walls',
  'found a jar full of someone else’s memories',
  'noticed the clock was running backward',
  'found footprints leading straight up the wall',
  'got a phone call from the future',
  'found a book that wrote itself as they read',
  'saw a door appear in a tree overnight',
  'discovered the gym became a portal at night',
  'swapped places with someone for the day',
];

const _storyHooks = [
  '',
  ' But it was locked.',
  ' And it was glowing.',
  ' Nobody else believed them.',
  ' It happened again the next day.',
  ' There was a note attached.',
  ' And it was getting closer.',
  ' Only one rule: tell no one.',
  ' The whole class was about to find out.',
  ' And there was no going back.',
];

// A mid-sentence twist clause (reads after "and"). The 5th slot — it takes the
// story space past a MILLION distinct openers (12×18×24×10×20 = 1,036,800).
const _storyTwists = [
  'a voice said their name',
  'everything changed',
  'it started to glow',
  'no one else could see it',
  'the room went quiet',
  'the lights flickered',
  'their shadow waved back',
  'time seemed to stop',
  'a tiny sound followed',
  'it was warm to the touch',
  'nothing was ever the same',
  'a breeze came from nowhere',
  'the clock began ticking backward',
  'something moved in the corner',
  'the whole class gasped',
  'a star fell outside the window',
  'the colors got brighter',
  'everyone leaned in closer',
  'the floor felt strangely soft',
  'a door appeared where none had been',
];

const _torThemes = [
  // Superpowers
  [
    'Fly',
    'Be invisible',
    'Super strength',
    'Talk to animals',
    'Read minds',
    'Freeze time',
    'Teleport anywhere',
    'Breathe underwater',
    'Super speed',
    'Control the weather',
  ],
  // Foods
  [
    'Pizza',
    'Tacos',
    'Ice cream',
    'Spaghetti',
    'Pancakes',
    'Chocolate',
    'Watermelon',
    'Mac and cheese',
    'Sushi',
    'Cookies',
  ],
  // Places to live
  [
    'A treehouse',
    'A castle',
    'A submarine',
    'A space station',
    'A jungle',
    'A snowy mountain',
    'A tropical island',
    'A floating cloud city',
  ],
  // Pets
  [
    'A dragon',
    'A robot dog',
    'A baby elephant',
    'A talking parrot',
    'A tiny dinosaur',
    'A penguin',
    'A glow-in-the-dark cat',
    'A pony',
  ],
  // Things to do
  [
    'Explore space',
    'Explore the deep sea',
    'Build a giant fort',
    'Direct a movie',
    'Invent a gadget',
    'Win an art contest',
    'Lead an expedition',
    'Throw the best party',
  ],
  // Ways to travel
  [
    'A hot air balloon',
    'A rocket',
    'A magic carpet',
    'A giant bird',
    'A speedboat',
    'A teleporter',
    'A dragon',
    'Roller skates that never stop',
  ],
  // Animals to be
  [
    'A cheetah',
    'A dolphin',
    'An eagle',
    'A wolf',
    'A panda',
    'A tiger',
    'A kangaroo',
    'An owl',
    'A sea turtle',
    'A fox',
  ],
  // Seasons and weather
  [
    'A sunny day',
    'A snow day',
    'A rainy afternoon',
    'A windy day',
    'A foggy morning',
    'A rainbow after rain',
    'A warm summer night',
    'The first snowfall',
    'A breezy fall day',
  ],
  // School subjects
  [
    'Art class',
    'Music class',
    'Science',
    'Math',
    'Reading time',
    'Gym class',
    'Recess',
    'Computer class',
    'History',
    'Lunch',
  ],
  // Vacation spots
  [
    'The beach',
    'A theme park',
    'A national park',
    'A big city',
    'The mountains',
    'A water park',
    'A farm stay',
    'A campground',
    'An island resort',
    'A ski lodge',
  ],
  // Snacks
  [
    'Popcorn',
    'Pretzels',
    'Apple slices',
    'Fruit snacks',
    'Trail mix',
    'String cheese',
    'Granola bar',
    'Yogurt',
    'Veggie sticks and dip',
  ],
  // Sports
  [
    'Soccer',
    'Basketball',
    'Swimming',
    'Gymnastics',
    'Baseball',
    'Skateboarding',
    'Tennis',
    'Karate',
    'Hockey',
    'Track and field',
  ],
  // Magical creatures
  [
    'A unicorn',
    'A phoenix',
    'A mermaid',
    'A fairy',
    'A griffin',
    'A friendly giant',
    'A baby dragon',
    'A genie',
    'A centaur',
  ],
  // Ice-cream flavors
  [
    'Chocolate',
    'Vanilla',
    'Strawberry',
    'Mint chip',
    'Cookie dough',
    'Cookies and cream',
    'Bubblegum',
    'Rocky road',
    'Birthday cake',
    'Mango',
  ],
  // Things to collect
  [
    'Stickers',
    'Trading cards',
    'Seashells',
    'Cool rocks',
    'Toy cars',
    'Stuffed animals',
    'Comic books',
    'Marbles',
    'Stamps',
    'Friendship bracelets',
  ],
  // Hobbies
  [
    'Drawing',
    'Building with blocks',
    'Playing video games',
    'Baking',
    'Gardening',
    'Playing an instrument',
    'Doing puzzles',
    'Reading books',
    'Dancing',
    'Telling jokes',
  ],
];

/// The registry: kind → its generator. Kinds NOT here keep serving curated +
/// crowd items (riddles, fact/fib, charades, rhyme words — authored, not
/// combinable). `ContentEngine` consults this.
final Map<String, ContentGenerator> contentGenerators = {
  ContentKind.storyStarter: TemplateGenerator(
    kind: ContentKind.storyStarter,
    slots: const [
      _storyTimes,
      _storySubjects,
      _storyEvents,
      _storyHooks,
      _storyTwists,
    ],
    format: (p) => '${p[0]} ${p[1]} ${p[2]}, and ${p[4]}.${p[3]}',
  ),
  ContentKind.thisOrThat: PairGenerator(
    kind: ContentKind.thisOrThat,
    themes: _torThemes,
  ),
};

/// How many distinct items the generator for [kind] can make (for a "X
/// combinations" readout), or null if [kind] isn't generated.
int? contentSpaceFor(String kind) => contentGenerators[kind]?.space;
