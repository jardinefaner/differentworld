/// The content bank (docs/CONTENT_BANK.md) — activity content made once
/// and reused, served behind a source-agnostic interface.
///
/// This is the LOCAL implementation: curated seed lists in Dart with
/// in-session seen-tracking. The DB-backed [ContentSource]
/// (`content_items` + brokered-AI refill + crowd-grow) drops in behind the
/// same interface later, so activities never change.
library;

/// One banked item — a SEMANTIC_GRAPH noun. [fingerprint] is the de-dupe
/// key; [payload] is the shape the activity reads.
class ContentItem {
  const ContentItem({
    required this.kind,
    required this.fingerprint,
    required this.payload,
  });

  final String kind;
  final String fingerprint;
  final Map<String, Object?> payload;
}

/// Content kinds. Add a constant when a new activity needs banked content.
abstract class ContentKind {
  static const thisOrThat = 'this_or_that';
  static const category = 'category';

  /// A neutral sentence to perform (the "As If" acting game).
  static const line = 'line';

  /// An "as if" transformation — an emotion / character / situation to
  /// perform a [line] in.
  static const asIf = 'as_if';

  /// A riddle to solve aloud — payload `{prompt, answer}`. Authored
  /// answer-first (the answer is the seed; the riddle points at it).
  static const riddle = 'riddle';

  /// A true/false claim — payload `{statement, isTrue (bool), note}`.
  /// The room votes; Reveal shows the verdict + the real fact.
  static const factOrFib = 'fact_or_fib';

  /// A story opener the room builds on aloud — payload `{text}`.
  static const storyStarter = 'story_starter';

  /// A "plot twist!" card to drop into a story in progress — payload
  /// `{text}`.
  static const storyTwist = 'story_twist';

  /// A word for the room to rhyme with — payload `{word}`.
  static const rhymeWord = 'rhyme_word';

  /// A charades prompt to act out — payload `{word, category}`. The actor's
  /// phone shows the word; the room sees only the category.
  static const charades = 'charades';
}

/// Source-agnostic content access. Activities depend on THIS, not on where
/// the content lives. The DB bank implements the same shape.
abstract class ContentSource {
  /// The next unseen item of [kind], or null when the bank is dry.
  ContentItem? next(String kind);

  /// Up to [n] unseen items of [kind] (marks them seen), for a round.
  List<ContentItem> take(String kind, int n);

  /// Unseen items remaining for [kind].
  int remaining(String kind);
}

/// A local, in-session bank over curated seed lists. Serves unseen items,
/// de-duped by fingerprint; "seen" is tracked in memory for the session.
class LocalContentBank implements ContentSource {
  LocalContentBank(List<ContentItem> items) {
    for (final item in items) {
      // De-dupe at load — uniqueness is the bank's job, never the
      // activity's (docs/CONTENT_BANK.md §4).
      if (_seenFingerprints.add('${item.kind}/${item.fingerprint}')) {
        (_byKind[item.kind] ??= <ContentItem>[]).add(item);
      }
    }
  }

  /// Seed the bank with the curated content shipped in the app — the
  /// always-available offline floor.
  factory LocalContentBank.seeded() => LocalContentBank(curatedSeeds);

  /// The curated floor PLUS [extra] banked items (AI / crowd rows pulled
  /// from `content_items`). De-dupe at load collapses any overlap between
  /// a curated seed and a banked row that share a (kind, fingerprint).
  factory LocalContentBank.seededWith(Iterable<ContentItem> extra) =>
      LocalContentBank([...curatedSeeds, ...extra]);

  final Map<String, List<ContentItem>> _byKind = {};
  final Set<String> _seenFingerprints = <String>{};
  final Set<String> _served = <String>{};

  String _key(ContentItem i) => '${i.kind}/${i.fingerprint}';

  @override
  ContentItem? next(String kind) {
    for (final item in _byKind[kind] ?? const <ContentItem>[]) {
      if (_served.add(_key(item))) return item;
    }
    return null;
  }

  @override
  List<ContentItem> take(String kind, int n) {
    final out = <ContentItem>[];
    for (var i = 0; i < n; i++) {
      final item = next(kind);
      if (item == null) break;
      out.add(item);
    }
    return out;
  }

  @override
  int remaining(String kind) => (_byKind[kind] ?? const <ContentItem>[])
      .where((i) => !_served.contains(_key(i)))
      .length;

  /// Forget what's been served this session (e.g. play again).
  void reset() => _served.clear();
}

/// The curated content shipped in the app (docs/CONTENT_BANK.md §1, tier 2)
/// — kid-safe by construction, free, offline, global. The DB bank
/// (`content_items`) layers AI + crowd items on top of this floor via
/// [LocalContentBank.seededWith].
final List<ContentItem> curatedSeeds = <ContentItem>[
  ..._thisOrThatSeed,
  ..._categorySeed,
  ..._lineSeed,
  ..._asIfSeed,
  ..._riddleSeed,
  ..._factOrFibSeed,
  ..._storyStarterSeed,
  ..._storyTwistSeed,
  ..._rhymeWordSeed,
  ..._charadesSeed,
];

// ── Curated seeds ──────────────────────────────────────────────────────
// Kid-safe by construction (the curated tier, docs/CONTENT_BANK.md §1).
// Fingerprints are stable so the DB bank can de-dupe against these.

ContentItem _torOf(String a, String b) => ContentItem(
  kind: ContentKind.thisOrThat,
  fingerprint: '${a.toLowerCase()}|${b.toLowerCase()}',
  payload: {'a': a, 'b': b},
);

final List<ContentItem> _thisOrThatSeed = <ContentItem>[
  _torOf('Pizza', 'Tacos'),
  _torOf('Summer', 'Winter'),
  _torOf('Dogs', 'Cats'),
  _torOf('Be able to fly', 'Be invisible'),
  _torOf('Mountains', 'The ocean'),
  _torOf('Draw it', 'Build it'),
  _torOf('Morning', 'Night'),
  _torOf('Chocolate', 'Vanilla'),
  _torOf('Read the book', 'Watch the movie'),
  _torOf('Explore space', 'Explore the deep sea'),
  _torOf('Always sunny', 'Always snowy'),
  _torOf('Super speed', 'Super strength'),
  _torOf('Sweet', 'Salty'),
  _torOf('A big party', 'A quiet hangout'),
  _torOf('Time travel to the past', 'Time travel to the future'),
  _torOf('Sing', 'Dance'),
];

ContentItem _categoryOf(String label) => ContentItem(
  kind: ContentKind.category,
  fingerprint: label.toLowerCase(),
  payload: {'label': label},
);

final List<ContentItem> _categorySeed = <ContentItem>[
  _categoryOf('an animal'),
  _categoryOf('a food'),
  _categoryOf('a place in the world'),
  _categoryOf('something you find at school'),
  _categoryOf('a color'),
  _categoryOf('a sport or game'),
  _categoryOf('something in the kitchen'),
  _categoryOf('a job people do'),
  _categoryOf('something that flies'),
  _categoryOf('a thing in nature'),
  _categoryOf('something you wear'),
  _categoryOf('a kind of music'),
];

ContentItem _lineOf(String s) => ContentItem(
  kind: ContentKind.line,
  fingerprint: s.toLowerCase(),
  payload: {'text': s},
);

final List<ContentItem> _lineSeed = <ContentItem>[
  _lineOf('I lost my keys'),
  _lineOf('Look at that!'),
  _lineOf('We need to talk'),
  _lineOf('I made you something'),
  _lineOf('It is right behind you'),
  _lineOf("I can't believe it"),
  _lineOf('Are you sure about this?'),
  _lineOf("That's the one"),
  _lineOf('Here we go again'),
  _lineOf("I'll never forget this"),
];

ContentItem _asIfOf(String s) => ContentItem(
  kind: ContentKind.asIf,
  fingerprint: s.toLowerCase(),
  payload: {'text': s},
);

final List<ContentItem> _asIfSeed = <ContentItem>[
  _asIfOf("you're terrified"),
  _asIfOf('you just won a prize'),
  _asIfOf("you're a sleepy cat"),
  _asIfOf('it is a giant secret'),
  _asIfOf("you're a robot"),
  _asIfOf("you're a tiny mouse"),
  _asIfOf("you're SO excited"),
  _asIfOf("you're a grumpy giant"),
  _asIfOf("you're underwater"),
  _asIfOf("you're a news reporter"),
  _asIfOf("you're a wise old wizard"),
  _asIfOf('you are trying not to laugh'),
];

ContentItem _riddleOf(String prompt, String answer) => ContentItem(
  kind: ContentKind.riddle,
  fingerprint: answer.toLowerCase(),
  payload: {'prompt': prompt, 'answer': answer},
);

// Classic, kid-safe riddles (ages 4–12). Authored answer-first.
final List<ContentItem> _riddleSeed = <ContentItem>[
  _riddleOf('What has to be broken before you can use it?', 'An egg'),
  _riddleOf(
    "I'm tall when I'm young and short when I'm old. What am I?",
    'A candle',
  ),
  _riddleOf('What has hands but cannot clap?', 'A clock'),
  _riddleOf('What gets wetter the more it dries?', 'A towel'),
  _riddleOf('What has many teeth but cannot bite?', 'A comb'),
  _riddleOf('What has a neck but no head?', 'A bottle'),
  _riddleOf('What has legs but cannot walk?', 'A table'),
  _riddleOf('What goes up but never comes down?', 'Your age'),
  _riddleOf('What has an eye but cannot see?', 'A needle'),
  _riddleOf('What kind of room has no doors or windows?', 'A mushroom'),
  _riddleOf('What has a thumb and four fingers but is not alive?', 'A glove'),
  _riddleOf('What can you catch but not throw?', 'A cold'),
  _riddleOf("What has keys but can't open locks?", 'A piano'),
  _riddleOf(
    'The more you take, the more you leave behind. What are they?',
    'Footsteps',
  ),
  _riddleOf('What is full of holes but still holds water?', 'A sponge'),
  _riddleOf('What has a head and a tail but no body?', 'A coin'),
];

ContentItem _factOf(
  String statement, {
  required bool isTrue,
  required String note,
}) => ContentItem(
  kind: ContentKind.factOrFib,
  fingerprint: statement.toLowerCase(),
  payload: {'statement': statement, 'isTrue': isTrue, 'note': note},
);

// Kid-safe true/false claims (ages 4–12). Mix of true + fib, each with the
// real fact for the reveal.
final List<ContentItem> _factOrFibSeed = <ContentItem>[
  _factOf(
    'A group of flamingos is called a flamboyance.',
    isTrue: true,
    note: 'True — a flamboyance of flamingos!',
  ),
  _factOf(
    'Octopuses have three hearts.',
    isTrue: true,
    note: 'True — two pump blood to the gills, one to the body.',
  ),
  _factOf(
    'The Great Wall of China is easily seen from space with your eyes.',
    isTrue: false,
    note: 'Fib — it is far too narrow to see unaided from orbit.',
  ),
  _factOf(
    'Honey never spoils.',
    isTrue: true,
    note: 'True — sealed honey can last thousands of years.',
  ),
  _factOf(
    'A goldfish only remembers things for three seconds.',
    isTrue: false,
    note: 'Fib — goldfish can remember things for months.',
  ),
  _factOf(
    'Some turtles can breathe through their bottoms.',
    isTrue: true,
    note: 'True — through a back opening, in cold water.',
  ),
  _factOf(
    'Bananas grow on trees.',
    isTrue: false,
    note: 'Fib — banana plants are giant herbs, not trees.',
  ),
  _factOf(
    'A day on Venus is longer than a whole year on Venus.',
    isTrue: true,
    note: 'True — Venus spins very, very slowly.',
  ),
  _factOf(
    'Carrots give you the power to see in the dark.',
    isTrue: false,
    note: 'Fib — good for you, but that was a wartime myth.',
  ),
  _factOf(
    'Wombat poop is shaped like little cubes.',
    isTrue: true,
    note: 'True — really!',
  ),
  _factOf(
    'Spiders are insects.',
    isTrue: false,
    note: 'Fib — spiders are arachnids (8 legs, not 6).',
  ),
  _factOf(
    'A bolt of lightning is hotter than the surface of the sun.',
    isTrue: true,
    note: 'True — about five times hotter.',
  ),
  _factOf("A shrimp's heart is in its head.", isTrue: true, note: 'True!'),
  _factOf(
    'Lightning never strikes the same place twice.',
    isTrue: false,
    note: 'Fib — it often hits the same tall spot again.',
  ),
  _factOf(
    'About 1.3 million Earths could fit inside the sun.',
    isTrue: true,
    note: 'True — the sun is enormous.',
  ),
  _factOf(
    'Chameleons change color to hide against any background.',
    isTrue: false,
    note: 'Fib — mostly to show mood and temperature.',
  ),
];

ContentItem _starterOf(String text) => ContentItem(
  kind: ContentKind.storyStarter,
  fingerprint: text.toLowerCase(),
  payload: {'text': text},
);

// Story openers the room builds on aloud — one line each, around the circle.
final List<ContentItem> _storyStarterSeed = <ContentItem>[
  _starterOf('One morning, a kid woke up and could talk to animals.'),
  _starterOf('A tiny door appeared at the back of the room.'),
  _starterOf('The new kid had a backpack that was bigger on the inside.'),
  _starterOf("Everyone's shadow started doing its own thing."),
  _starterOf('A paper airplane landed on the desk with a secret map.'),
  _starterOf("The class pet left a note that said 'meet me at midnight.'"),
  _starterOf('It started raining something that was not water.'),
  _starterOf('A robot showed up asking for help finding its way home.'),
  _starterOf('The oldest tree in the yard whispered a name.'),
  _starterOf('A treasure chest washed up at recess.'),
  _starterOf('Everyone could fly — but only for one minute a day.'),
  _starterOf('The cafeteria food turned out to be a little bit magic.'),
];

ContentItem _twistOf(String text) => ContentItem(
  kind: ContentKind.storyTwist,
  fingerprint: text.toLowerCase(),
  payload: {'text': text},
);

// "Plot twist!" cards to drop into a story in progress.
final List<ContentItem> _storyTwistSeed = <ContentItem>[
  _twistOf('Suddenly, the smallest one saves the day.'),
  _twistOf('It turns out someone has been keeping a secret.'),
  _twistOf('All the lights go out.'),
  _twistOf('A brand-new friend appears from nowhere.'),
  _twistOf('Everything starts happening backward.'),
  _twistOf('The map was upside down the whole time.'),
  _twistOf('The answer was hiding in plain sight.'),
  _twistOf('A door opens that was never there before.'),
];

ContentItem _rhymeOf(String word) => ContentItem(
  kind: ContentKind.rhymeWord,
  fingerprint: word.toLowerCase(),
  payload: {'word': word},
);

// Rhyme-friendly words (ages 4–12) — each has lots of easy rhymes.
final List<ContentItem> _rhymeWordSeed = <ContentItem>[
  _rhymeOf('cat'),
  _rhymeOf('day'),
  _rhymeOf('light'),
  _rhymeOf('star'),
  _rhymeOf('blue'),
  _rhymeOf('tree'),
  _rhymeOf('song'),
  _rhymeOf('run'),
  _rhymeOf('snow'),
  _rhymeOf('ball'),
  _rhymeOf('hop'),
  _rhymeOf('ring'),
  _rhymeOf('bee'),
  _rhymeOf('cake'),
  _rhymeOf('fun'),
  _rhymeOf('top'),
];

ContentItem _charadesOf(String word, String category) => ContentItem(
  kind: ContentKind.charades,
  fingerprint: word.toLowerCase(),
  payload: {'word': word, 'category': category},
);

// Act-it-out prompts (ages 4–12). Order is stable so every device in a live
// session maps the same index to the same word (no shuffle — sync needs it).
final List<ContentItem> _charadesSeed = <ContentItem>[
  _charadesOf('A penguin', 'Animal'),
  _charadesOf('A monkey', 'Animal'),
  _charadesOf('A snake', 'Animal'),
  _charadesOf('A T-rex', 'Animal'),
  _charadesOf('An elephant', 'Animal'),
  _charadesOf('A kangaroo', 'Animal'),
  _charadesOf('Brushing your teeth', 'Action'),
  _charadesOf('Tying your shoes', 'Action'),
  _charadesOf('Eating spaghetti', 'Action'),
  _charadesOf('Flying a kite', 'Action'),
  _charadesOf('Sneezing', 'Action'),
  _charadesOf('Climbing a ladder', 'Action'),
  _charadesOf('A superhero', 'Character'),
  _charadesOf('A robot', 'Character'),
  _charadesOf('A wizard', 'Character'),
  _charadesOf('A pirate', 'Character'),
  _charadesOf('A sleepy baby', 'Character'),
  _charadesOf('A ballerina', 'Character'),
  _charadesOf('Shooting a basketball', 'Sport'),
  _charadesOf('Surfing a wave', 'Sport'),
  _charadesOf('A chef cooking', 'Job'),
  _charadesOf('A firefighter', 'Job'),
  _charadesOf('A farmer', 'Job'),
  _charadesOf('Conducting an orchestra', 'Job'),
];
