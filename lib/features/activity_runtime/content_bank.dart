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

  /// A picture card from a deck (docs/CARD_GAMES.md) — payload
  /// `{id, label, image, category, letter, deck}`. The `image` is a bundled
  /// asset path or a Storage URL; the word lives in `label` as DATA so games
  /// can hide / show / match it. One kind, read by every card game.
  static const picture = 'picture';

  /// A **"Do It"** — a real-world action you get up and PERFORM, not answer in
  /// your head (build · find · move · make · ask · help) — payload
  /// `{text, verb, emoji}`. THE anti-ephemeral genre (docs/VISION.md
  /// 2026-06-18): where the games above are played-and-gone, doing a Do-It
  /// writes an accumulating `EntryKind.didIt` with evidence (a photo / count /
  /// note) into the child's Book. The screen prompts; the room does it; the
  /// proof persists. Kid-first, but the genre is universal (meetings,
  /// gatherings — anywhere people share proximity).
  static const doIt = 'do_it';

  /// A **Question of the Day** — an open, answerable-many-ways prompt
  /// (docs/VISION.md 2026-06-19), payload `{text}`. Followed by a captured
  /// response (a drawing / sentence) that flows into the child's Book — "their
  /// learning with intentionality." No right answer; perspective + growth.
  static const question = 'question';

  /// A **Quote of the Day** — a short, kid-legible line to sit with, payload
  /// `{text, author?}`. Like the question, it's answered with an
  /// interpretation (what does it mean to you?).
  static const quote = 'quote';
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
  ..._doItSeed,
  ..._questionSeed,
  ..._quoteSeed,
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
  // — expanded set (broad, distinct from the above) —
  _categoryOf('a fruit'),
  _categoryOf('a vegetable'),
  _categoryOf('a bird'),
  _categoryOf('an animal that lives in water'),
  _categoryOf('an insect or bug'),
  _categoryOf('an animal you might see at a zoo'),
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
  // — expanded set —
  _lineOf("It's your turn now"),
  _lineOf('I have to tell you something'),
  _lineOf('Open the door'),
  _lineOf("There's something in the box"),
  _lineOf("We're almost there"),
  _lineOf('I read your note'),
  _lineOf('I found it'),
  _lineOf('Wait right here'),
  _lineOf('Tell me what you saw'),
  _lineOf('This is the last one'),
  _lineOf('Come closer'),
  _lineOf("I'm going in"),
  _lineOf("It's starting"),
  _lineOf('You forgot something'),
  _lineOf("I'll be right back"),
  _lineOf('Nobody else knows'),
  _lineOf('I made up my mind'),
  _lineOf('Say it again'),
  _lineOf('The lights went out'),
  _lineOf('I saw your face'),
  _lineOf("It's almost over"),
  _lineOf('Close your eyes'),
  _lineOf('I counted them all'),
  _lineOf('Something is different'),
  _lineOf('Look up'),
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
  // — expanded set —
  _asIfOf("you're freezing cold"),
  _asIfOf("you're a sneaky spy"),
  _asIfOf('you just smelled something stinky'),
  _asIfOf("you're a proud lion"),
  _asIfOf("you're trying not to fall asleep"),
  _asIfOf("you're a hungry shark"),
  _asIfOf('it is the best day ever'),
  _asIfOf("you're a creaky old robot running low on battery"),
  _asIfOf("you're a bouncy puppy"),
  _asIfOf('you just stepped in gum'),
  _asIfOf("you're a fancy royal queen"),
  _asIfOf("you're SUPER sleepy"),
  _asIfOf("you're a buzzing bee"),
  _asIfOf('you forgot what you were saying'),
  _asIfOf("you're a brave superhero"),
  _asIfOf("you're trying to keep a surprise party secret"),
  _asIfOf("you're a slow, sleepy sloth"),
  _asIfOf('you just heard the funniest joke'),
  _asIfOf("you're a pirate captain"),
  _asIfOf("you're walking on hot sand"),
  _asIfOf("you're a curious little alien"),
  _asIfOf("you're SO bored"),
  _asIfOf("you're a wobbly newborn baby deer"),
  _asIfOf('you just won the big game'),
  _asIfOf("you're a sneaky cat stalking a toy"),
  _asIfOf("you're whispering so nobody wakes up"),
  _asIfOf("you're a tired marathon runner at the finish line"),
  _asIfOf("you're a chatty parrot"),
  _asIfOf('you just saw a shooting star'),
  _asIfOf("you're a grumpy bear who woke up too early"),
  _asIfOf("you're stuck in slow motion"),
  _asIfOf("you're a tiny ant carrying a huge crumb"),
  _asIfOf("you're trying not to sneeze"),
  _asIfOf("you're a wise old turtle"),
  _asIfOf('you just got the best present'),
  _asIfOf("you're a shy little turtle peeking out"),
  _asIfOf("you're a cheerful tour guide"),
  _asIfOf("you're floating in outer space"),
  _asIfOf("you're a melting ice cream cone"),
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
  // — expanded set (kid-safe, answer-first) —
  _riddleOf(
    'What can travel all around the world while staying in one corner?',
    'A stamp',
  ),
  _riddleOf('What runs all around the yard but never moves?', 'A fence'),
  _riddleOf('What has four legs but only one foot?', 'A bed'),
  _riddleOf('What goes up and down but never moves?', 'The stairs'),
  _riddleOf(
    'What has a bed but never sleeps, and a mouth but never eats?',
    'A river',
  ),
  _riddleOf('What kind of band never plays music?', 'A rubber band'),
  _riddleOf('What gets bigger the more you take away from it?', 'A hole'),
  _riddleOf('What has wheels and flies but is not a plane?', 'A garbage truck'),
  _riddleOf(
    'What has a handle and a spout and sings when it is hot?',
    'A kettle',
  ),
  _riddleOf('What kind of cup can you never drink from?', 'A cupcake'),
  _riddleOf(
    'What can hold a lot of water but is full of holes on top?',
    'A watering can',
  ),
  _riddleOf(
    'What has bristles and helps keep your teeth clean?',
    'A toothbrush',
  ),
  _riddleOf('What animal keeps the best time?', 'A watchdog'),
  _riddleOf('What has a trunk but is not a tree or a car?', 'An elephant'),
  _riddleOf('What can hop and has long ears and a fluffy tail?', 'A rabbit'),
  _riddleOf('What is black and white and waddles on the ice?', 'A penguin'),
  _riddleOf(
    'What buzzes from flower to flower and makes something sweet?',
    'A bee',
  ),
  _riddleOf(
    'What changes from a caterpillar into something with wings?',
    'A butterfly',
  ),
  _riddleOf('What spins a web to catch its dinner?', 'A spider'),
  _riddleOf('What barks and wags its tail when it is happy?', 'A dog'),
  _riddleOf(
    'What has a long neck and eats leaves from tall trees?',
    'A giraffe',
  ),
  _riddleOf("What says 'moo' and gives us milk?", 'A cow'),
  _riddleOf('What slow green animal has a hard shell to hide in?', 'A turtle'),
  _riddleOf(
    'What is so light it has no weight, yet you cannot hold it for long?',
    'Your breath',
  ),
  _riddleOf('What comes down but never goes up?', 'Rain'),
  _riddleOf(
    'What has a tail and a head but is made only of light at night?',
    'A shooting star',
  ),
  _riddleOf('What lives in the sky by day and gives us warm light?', 'The sun'),
  _riddleOf('What glows at night and changes its shape each week?', 'The moon'),
  _riddleOf(
    'What is round, blue and green, and is home to all of us?',
    'The Earth',
  ),
  _riddleOf(
    'What grows from a tiny seed into something tall and leafy?',
    'A tree',
  ),
  _riddleOf(
    'What falls in winter, is cold and white, and you can build with it?',
    'Snow',
  ),
  _riddleOf(
    'What has petals and a stem and smells sweet in the garden?',
    'A flower',
  ),
  _riddleOf(
    "What is yellow, curved, and a monkey's favorite snack?",
    'A banana',
  ),
  _riddleOf('What is round and red and keeps the doctor away?', 'An apple'),
  _riddleOf('What is white and cold and you eat it on a hot day?', 'Ice cream'),
  _riddleOf(
    'What is round, flat, and has cheese on top before it is baked?',
    'A pizza',
  ),
  _riddleOf(
    'What is orange and crunchy and a rabbit loves to eat?',
    'A carrot',
  ),
  _riddleOf('What is sweet, sticky, and made by busy bees?', 'Honey'),
  _riddleOf(
    'What is brown and sweet and melts in your warm hand?',
    'Chocolate',
  ),
  _riddleOf(
    'What is soft, white, and you rest your sleepy head on it?',
    'A pillow',
  ),
  _riddleOf(
    'What is long and thin, you slurp it up, and it can be very saucy?',
    'Spaghetti',
  ),
  _riddleOf('What has five toes but is not your hand?', 'A foot'),
  _riddleOf(
    'What two things can see but are not a camera, and blink when you are sleepy?',
    'Your eyes',
  ),
  _riddleOf(
    'What helps you smell a flower and sits in the middle of your face?',
    'Your nose',
  ),
  _riddleOf('What can hear a whisper but cannot talk?', 'Your ear'),
  _riddleOf(
    'What grows on your head and you brush every morning?',
    'Your hair',
  ),
  _riddleOf('What thumps inside your chest all day and night?', 'Your heart'),
  _riddleOf('What gets shorter the more you use it to write?', 'A pencil'),
  _riddleOf(
    'What has many pages but is not a calendar, and tells a story?',
    'A book',
  ),
  _riddleOf(
    'What can you erase but is not a mistake, and cleans a pencil mark?',
    'An eraser',
  ),
  _riddleOf(
    'What has lines and numbers and helps you draw a straight edge?',
    'A ruler',
  ),
  _riddleOf(
    'What is sticky on one side and holds your papers together?',
    'Tape',
  ),
  _riddleOf('What has many colors and shows up after the rain?', 'A rainbow'),
  _riddleOf(
    'What is loud, booms in the sky, and follows a flash of light?',
    'Thunder',
  ),
  _riddleOf(
    'What is white and fluffy and floats high up in the sky?',
    'A cloud',
  ),
  _riddleOf(
    'What you cannot see, but it moves the leaves and flies a kite?',
    'The wind',
  ),
  _riddleOf(
    'What has 7 days but no food, and starts again every Monday?',
    'A week',
  ),
  _riddleOf(
    'What comes once in a minute, twice in a moment, but never in a thousand years?',
    'The letter M',
  ),
  _riddleOf('What shape has three sides and three corners?', 'A triangle'),
  _riddleOf(
    'What shape is perfectly round with no corners at all?',
    'A circle',
  ),
  _riddleOf('What letter is a question all by itself?', 'The letter Y'),
  _riddleOf(
    'What starts with the letter T, is full of T, and ends in T?',
    'A teapot',
  ),
  _riddleOf(
    'What is always coming tomorrow but never actually arrives today?',
    'Tomorrow',
  ),
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
  // — expanded set (kid-safe; each verdict fact-checked) —
  _factOf(
    'A newborn baby has more bones than a grown-up.',
    isTrue: true,
    note: 'True — babies have about 300; many fuse into the 206 adults have.',
  ),
  _factOf(
    'Sharks have skeletons made of bone, just like us.',
    isTrue: false,
    note: "Fib — a shark's skeleton is made of bendy cartilage, not bone.",
  ),
  _factOf(
    'A tomato is, scientifically speaking, a fruit.',
    isTrue: true,
    note: "True — it grows from a flower and holds seeds, so it's a fruit.",
  ),
  _factOf(
    'Mercury is the hottest planet because it is closest to the sun.',
    isTrue: false,
    note:
        'Fib — Venus is hottest; its thick air traps the heat like a blanket.',
  ),
  _factOf(
    'A cloud can weigh as much as a hundred elephants.',
    isTrue: true,
    note: 'True — a big fluffy cloud holds tons of tiny water droplets.',
  ),
  _factOf(
    "An ostrich's eye is bigger than its brain.",
    isTrue: true,
    note: 'True — those giant eyes are larger than its brain.',
  ),
  _factOf(
    'Sound travels faster than light.',
    isTrue: false,
    note:
        'Fib — light is way faster, which is why you see lightning before thunder.',
  ),
  _factOf(
    'Polar bears have black skin under their white fur.',
    isTrue: true,
    note: 'True — black skin under clear, hollow hairs that look white.',
  ),
  _factOf(
    'The Eiffel Tower can grow taller on a hot day.',
    isTrue: true,
    note: 'True — the metal expands in heat, so it gets a bit taller.',
  ),
  _factOf(
    "Goldfish can't see the color red.",
    isTrue: false,
    note: "Fib — goldfish can actually see lots of colors, even some we can't.",
  ),
  _factOf(
    'A jellyfish has no brain, no heart, and no bones.',
    isTrue: true,
    note: "True — and they're about 95% water!",
  ),
  _factOf(
    'The Pacific is the biggest ocean on Earth.',
    isTrue: true,
    note: "True — it's the largest, bigger than all the land combined.",
  ),
  _factOf(
    'A snail can sleep for up to three years.',
    isTrue: true,
    note: 'True — some snails sleep a very long time to wait out dry weather.',
  ),
  _factOf(
    'Your stomach gets a brand-new lining every few days.',
    isTrue: true,
    note: "True — it remakes its lining so it doesn't digest itself.",
  ),
  _factOf(
    'Mount Everest is the tallest mountain measured from the sea floor.',
    isTrue: false,
    note: "Fib — measured base-to-top, Hawaii's Mauna Kea is taller.",
  ),
  _factOf(
    'Bees can recognize human faces.',
    isTrue: true,
    note: 'True — honeybees can learn to tell faces apart.',
  ),
  _factOf(
    'There is no sound in outer space.',
    isTrue: true,
    note: 'True — sound needs air or water, and space is empty.',
  ),
  _factOf(
    'Carrots were originally purple, not orange.',
    isTrue: true,
    note: 'True — old carrots were purple, white, and yellow long ago.',
  ),
  _factOf(
    'Lightning is colder than a snowball.',
    isTrue: false,
    note: "Fib — a lightning bolt is hotter than the sun's surface!",
  ),
  _factOf(
    'A hummingbird can fly backwards.',
    isTrue: true,
    note: "True — it's the only bird that can fly backward and hover.",
  ),
  _factOf(
    'Antarctica is the wettest, rainiest place on Earth.',
    isTrue: false,
    note: "Fib — it's actually a desert; it almost never rains there.",
  ),
  _factOf(
    'The human nose can remember thousands of different smells.',
    isTrue: true,
    note: 'True — your nose can tell apart a huge number of smells.',
  ),
  _factOf(
    'The Sahara Desert never, ever gets snow.',
    isTrue: false,
    note: 'Fib — rarely, parts of the Sahara have had a dusting of snow.',
  ),
  _factOf(
    'A group of crows is called a murder.',
    isTrue: true,
    note: "True — a 'murder' of crows is the real name.",
  ),
  _factOf(
    'Saturn is light enough that it would float in water.',
    isTrue: true,
    note: "True — it's so puffy it's less dense than water.",
  ),
  _factOf(
    'Eating an apple wakes you up better than a cup of coffee.',
    isTrue: false,
    note: 'Fib — an apple has natural sugar, but no caffeine like coffee.',
  ),
  _factOf(
    'An octopus can squeeze through a hole the size of a coin.',
    isTrue: true,
    note: 'True — with no bones, it fits through tiny gaps.',
  ),
  _factOf(
    'The Great Barrier Reef is the largest living thing on Earth.',
    isTrue: true,
    note: "True — it's so big it can be seen from space.",
  ),
  _factOf(
    'Rainbows only ever appear during the daytime.',
    isTrue: false,
    note: "Fib — on bright nights the moon can make a faint 'moonbow.'",
  ),
  _factOf(
    'A cat has more bones than a human.',
    isTrue: true,
    note: 'True — cats have about 230 bones; we have 206.',
  ),
  _factOf(
    'Your heart beats about 100,000 times every day.',
    isTrue: true,
    note: 'True — roughly 100,000 beats a day, without you trying.',
  ),
  _factOf(
    'Penguins live at the North Pole with polar bears.',
    isTrue: false,
    note: 'Fib — wild penguins live in the south; polar bears in the north.',
  ),
  _factOf(
    'Some frogs can freeze solid in winter and hop away in spring.',
    isTrue: true,
    note: 'True — the wood frog freezes, then thaws and hops off.',
  ),
  _factOf(
    'Light from the sun takes about 8 minutes to reach Earth.',
    isTrue: true,
    note: 'True — sunlight travels 8 minutes before we see it.',
  ),
  _factOf(
    'Chewing gum stays stuck in your stomach for seven years.',
    isTrue: false,
    note: "Fib — your body just passes it through; it doesn't stay for years.",
  ),
  _factOf(
    'The country of Russia spans eleven different time zones.',
    isTrue: true,
    note: "True — it's so wide it crosses 11 time zones.",
  ),
  _factOf(
    'It is impossible to sneeze with your eyes open.',
    isTrue: false,
    note: "Fib — it's hard, but some people can do it.",
  ),
  _factOf(
    'Cows have best friends and get stressed when apart.',
    isTrue: true,
    note: 'True — cows bond with buddies and miss them when separated.',
  ),
  _factOf(
    'Jupiter is the largest planet in our solar system.',
    isTrue: true,
    note: 'True — over 1,300 Earths could fit inside Jupiter.',
  ),
  _factOf(
    'Bananas are radioactive.',
    isTrue: true,
    note: 'True — a tiny, harmless amount, from the potassium in them.',
  ),
  _factOf(
    "Bats are blind and can't see anything at all.",
    isTrue: false,
    note: 'Fib — bats can see; many also use sound to find their way.',
  ),
  _factOf(
    'A bolt of lightning contains enough energy to toast bread for years.',
    isTrue: true,
    note: 'True — one bolt holds a huge burst of energy.',
  ),
  _factOf(
    'The ocean produces more than half the oxygen we breathe.',
    isTrue: true,
    note: "True — tiny ocean plants make most of Earth's oxygen.",
  ),
  _factOf(
    'George Washington had wooden teeth.',
    isTrue: false,
    note: 'Fib — his false teeth were ivory and metal, not wood.',
  ),
  _factOf(
    "A giraffe's tongue can be longer than your arm.",
    isTrue: true,
    note: 'True — about 18–20 inches, and bluish-purple!',
  ),
  _factOf(
    'Earth is the only planet not named after a god.',
    isTrue: true,
    note: "True — the others are named for Roman gods; Earth isn't.",
  ),
  _factOf(
    'Spinach makes your muscles grow instantly, like in cartoons.',
    isTrue: false,
    note: 'Fib — spinach is healthy, but muscles grow slowly with exercise.',
  ),
  _factOf(
    'Some sea stars can grow a whole new arm if they lose one.',
    isTrue: true,
    note: 'True — a few can even grow a new body from one arm.',
  ),
  _factOf(
    'A flash of lightning is brighter than a million light bulbs.',
    isTrue: true,
    note: "True — it's incredibly bright for a split second.",
  ),
  _factOf(
    'The pyramids of Egypt were built by aliens.',
    isTrue: false,
    note: 'Fib — they were built by thousands of skilled Egyptian workers.',
  ),
  _factOf(
    'Your bones are stronger than steel, pound for pound.',
    isTrue: true,
    note: 'True — bone is light but very strong for its weight.',
  ),
  _factOf(
    'A starfish has eyes on the tips of its arms.',
    isTrue: true,
    note: 'True — tiny eye spots sit at the end of each arm.',
  ),
  _factOf(
    'The Amazon is the longest river in the world.',
    isTrue: false,
    note: 'Fib — the Nile is usually counted as the longest.',
  ),
  _factOf(
    'Snowflakes almost always have six sides.',
    isTrue: true,
    note: 'True — the way water freezes gives them six points.',
  ),
  _factOf(
    "A koala's fingerprints look almost exactly like a human's.",
    isTrue: true,
    note: 'True — so alike they could fool a crime scene!',
  ),
  _factOf(
    'You use only ten percent of your brain.',
    isTrue: false,
    note: 'Fib — you use all of it, just different parts at different times.',
  ),
  _factOf(
    'Some kinds of bamboo can grow almost a meter in a single day.',
    isTrue: true,
    note: 'True — bamboo is one of the fastest-growing plants on Earth.',
  ),
  _factOf(
    'Owls can turn their heads almost all the way around.',
    isTrue: true,
    note: 'True — about three-quarters of a full circle.',
  ),
  _factOf(
    'The full moon is bigger than the sun.',
    isTrue: false,
    note: 'Fib — the sun is far bigger; it just looks small from far away.',
  ),
  _factOf(
    'A teaspoon of soil holds more tiny living things than people on Earth.',
    isTrue: true,
    note: 'True — soil is packed with billions of microbes.',
  ),
  _factOf(
    'Dolphins sleep with one half of their brain awake.',
    isTrue: true,
    note: 'True — so they keep swimming and come up to breathe.',
  ),
  _factOf(
    'Glass is actually a slow-moving liquid that drips over time.',
    isTrue: false,
    note: "Fib — old glass is a solid; it doesn't slowly drip.",
  ),
  _factOf(
    "An adult human's blood vessels could wrap around Earth many times.",
    isTrue: true,
    note: "True — laid end to end they'd circle the planet several times.",
  ),
  _factOf(
    'Hawaii moves a few centimeters closer to Japan each year.',
    isTrue: true,
    note: "True — the Earth's plates drift, nudging them together slowly.",
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
  _twistOf('Suddenly, everyone is wearing the exact same hat.'),
  _twistOf("It turns out the whole thing was someone's brilliant plan."),
  _twistOf('A second moon appears in the sky.'),
  _twistOf('Everything that was lost is found in one big pile.'),
  _twistOf('The quietest one finally speaks up — and changes everything.'),
  _twistOf('It all started because of a single missing sock.'),
  _twistOf('Suddenly, the floor is made of jelly.'),
  _twistOf('A talking cat strolls in and clears its throat.'),
  _twistOf('It turns out they were in the wrong place the entire time.'),
  _twistOf('Everyone swaps places with the person next to them.'),
  _twistOf('A giant present is waiting at the top of the hill.'),
  _twistOf('The rules of the game just changed completely.'),
  _twistOf('Suddenly, gravity decides to take a break.'),
  _twistOf(
    'It turns out the treasure was friendship all along — but also actual gold.',
  ),
  _twistOf('A trail of glitter leads somewhere unexpected.'),
  _twistOf('The smallest clue turns out to be the biggest one.'),
  _twistOf("Everyone's pockets are suddenly full of snacks."),
  _twistOf('A wise old turtle offers exactly the right advice.'),
  _twistOf('It turns out two of them are actually long-lost twins.'),
  _twistOf('The ground opens up to reveal a secret staircase.'),
  _twistOf('Suddenly, everything is twice as big.'),
  _twistOf('A letter arrives addressed to the bravest one in the room.'),
  _twistOf('It turns out the villain just wanted a friend.'),
  _twistOf('Everyone starts speaking in rhyme.'),
  _twistOf('A rainbow bridge appears out of nowhere.'),
  _twistOf('The slowest one wins the race after all.'),
  _twistOf('Suddenly, they can all understand the birds.'),
  _twistOf('It turns out the key fit a different lock entirely.'),
  _twistOf('A surprise party was being planned the whole time.'),
  _twistOf('The one nobody noticed has the answer.'),
  _twistOf('Suddenly, it begins to snow indoors.'),
  _twistOf('A forgotten promise suddenly comes true.'),
  _twistOf('It turns out everyone had the same dream last night.'),
  _twistOf('A bell rings, and the whole room transforms.'),
  _twistOf('The last one to arrive holds the missing piece.'),
  _twistOf('Suddenly, the walls start to giggle.'),
  _twistOf("A map appears on the back of someone's hand."),
  _twistOf('It turns out the long way around was the right one.'),
  _twistOf("Everyone's reflection winks at the same moment."),
  _twistOf("A second chance shows up right when it's needed most."),
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
  // — expanded set —
  _rhymeOf('dog'),
  _rhymeOf('bug'),
  _rhymeOf('bear'),
  _rhymeOf('moon'),
  _rhymeOf('hat'),
  _rhymeOf('pig'),
  _rhymeOf('duck'),
  _rhymeOf('bed'),
  _rhymeOf('rain'),
  _rhymeOf('lake'),
  _rhymeOf('mouse'),
  _rhymeOf('fish'),
  _rhymeOf('boat'),
  _rhymeOf('bell'),
  _rhymeOf('nose'),
  _rhymeOf('king'),
  _rhymeOf('car'),
  _rhymeOf('sun'),
  _rhymeOf('wall'),
  _rhymeOf('cap'),
  _rhymeOf('pan'),
  _rhymeOf('corn'),
  _rhymeOf('door'),
  _rhymeOf('nest'),
  _rhymeOf('hand'),
  _rhymeOf('seed'),
  _rhymeOf('cow'),
  _rhymeOf('pie'),
  _rhymeOf('fox'),
  _rhymeOf('nut'),
  _rhymeOf('rope'),
  _rhymeOf('gate'),
  _rhymeOf('clock'),
  _rhymeOf('tail'),
  _rhymeOf('bone'),
  _rhymeOf('wheel'),
  _rhymeOf('drum'),
  _rhymeOf('shoe'),
  _rhymeOf('frog'),
  _rhymeOf('hen'),
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
  // — expanded set (appended, never reordered: live-session index stability) —
  _charadesOf('A frog', 'Animal'),
  _charadesOf('A crab', 'Animal'),
  _charadesOf('A rabbit', 'Animal'),
  _charadesOf('A gorilla', 'Animal'),
  _charadesOf('A chicken', 'Animal'),
  _charadesOf('A lion', 'Animal'),
  _charadesOf('An owl', 'Animal'),
  _charadesOf('A spider', 'Animal'),
  _charadesOf('A turtle', 'Animal'),
  _charadesOf('A bee', 'Animal'),
  _charadesOf('A horse', 'Animal'),
  _charadesOf('A duck', 'Animal'),
  _charadesOf('A bear', 'Animal'),
  _charadesOf('A flamingo', 'Animal'),
  _charadesOf('A worm', 'Animal'),
  _charadesOf('A butterfly', 'Animal'),
  _charadesOf('Blowing out birthday candles', 'Action'),
  _charadesOf('Brushing your hair', 'Action'),
  _charadesOf('Jumping rope', 'Action'),
  _charadesOf('Washing your hands', 'Action'),
  _charadesOf('Putting on a backpack', 'Action'),
  _charadesOf('Sweeping the floor', 'Action'),
  _charadesOf('Yawning and stretching', 'Action'),
  _charadesOf('Painting a picture', 'Action'),
  _charadesOf('Tip-toeing quietly', 'Action'),
  _charadesOf('Building a tower of blocks', 'Action'),
  _charadesOf('Waving goodbye', 'Action'),
  _charadesOf('Catching a bug in your hands', 'Action'),
  _charadesOf('Stomping in puddles', 'Action'),
  _charadesOf('Buttoning a coat', 'Action'),
  _charadesOf('A clown', 'Character'),
  _charadesOf('A king', 'Character'),
  _charadesOf('A fairy', 'Character'),
  _charadesOf('A knight', 'Character'),
  _charadesOf('A cowboy', 'Character'),
  _charadesOf('A mermaid', 'Character'),
  _charadesOf('A grumpy troll', 'Character'),
  _charadesOf('A scarecrow', 'Character'),
  _charadesOf('A sneaky ninja', 'Character'),
  _charadesOf('Swinging a baseball bat', 'Sport'),
  _charadesOf('Kicking a soccer ball', 'Sport'),
  _charadesOf('Swimming', 'Sport'),
  _charadesOf('Bowling', 'Sport'),
  _charadesOf('Doing a karate kick', 'Sport'),
  _charadesOf('Ice skating', 'Sport'),
  _charadesOf('Serving in tennis', 'Sport'),
  _charadesOf('Doing a gymnastics flip', 'Sport'),
  _charadesOf('Skateboarding', 'Sport'),
  _charadesOf('A police officer', 'Job'),
  _charadesOf('A doctor', 'Job'),
  _charadesOf('A teacher', 'Job'),
  _charadesOf('A painter', 'Job'),
  _charadesOf('A mail carrier', 'Job'),
  _charadesOf('An astronaut', 'Job'),
  _charadesOf('A pilot', 'Job'),
  _charadesOf('A dentist', 'Job'),
  _charadesOf('A waiter', 'Job'),
  _charadesOf('A tree blowing in the wind', 'Thing'),
  _charadesOf('A melting ice cream cone', 'Thing'),
  _charadesOf('A bouncing ball', 'Thing'),
  _charadesOf('A rocket blasting off', 'Thing'),
  _charadesOf('A teapot that is boiling', 'Thing'),
  _charadesOf('A clock ticking', 'Thing'),
  _charadesOf('A flower opening up', 'Thing'),
  _charadesOf('A washing machine spinning', 'Thing'),
  _charadesOf('A popping piece of popcorn', 'Thing'),
  _charadesOf('An airplane flying', 'Thing'),
];

ContentItem _doItOf(String text, String verb, String emoji) => ContentItem(
  kind: ContentKind.doIt,
  fingerprint: text.toLowerCase(),
  payload: {'text': text, 'verb': verb, 'emoji': emoji},
);

// "Do It" — real-world actions you get up and PERFORM (not answer in your
// head). The anti-ephemeral genre: doing one leaves accumulating evidence
// (docs/VISION.md 2026-06-18). Kid-safe (4–12), no-typing, no right/wrong;
// `verb` is the action type (build · find · move · make · ask · help).
final List<ContentItem> _doItSeed = <ContentItem>[
  // build
  _doItOf(
    'Build the tallest tower you can — then knock it down gently.',
    'build',
    '🗼',
  ),
  _doItOf(
    'Stack these cups into a pyramid, then take it apart.',
    'build',
    '🥤',
  ),
  _doItOf('Build a fort big enough to sit inside.', 'build', '🏕️'),
  _doItOf('Make a bridge two blocks can roll across.', 'build', '🌉'),
  _doItOf('Build something that keeps a ball from rolling away.', 'build', '⚽'),
  _doItOf('Build a tower using only one hand.', 'build', '🤚'),
  // find
  _doItOf('Find 3 things in the room that are the same color.', 'find', '🟦'),
  _doItOf('Find something softer than your shoe.', 'find', '🧦'),
  _doItOf(
    'Find something that starts with the same sound as your name.',
    'find',
    '🔤',
  ),
  _doItOf('Find the smallest thing you can hold in one hand.', 'find', '🔎'),
  _doItOf(
    'Find something round, something flat, and something bumpy.',
    'find',
    '⭕',
  ),
  _doItOf('Find two things that are exactly the same.', 'find', '👀'),
  _doItOf(
    'Find something that would float and something that would sink.',
    'find',
    '💧',
  ),
  // move
  _doItOf('Move like the slowest animal you can think of.', 'move', '🐢'),
  _doItOf('Make the biggest shape you can with your whole body.', 'move', '🦋'),
  _doItOf('Walk heel-to-toe across the room without wobbling.', 'move', '🚶'),
  _doItOf('Balance on one foot while you count to ten.', 'move', '🦩'),
  _doItOf('Tiptoe across the room so quietly no one hears you.', 'move', '🤫'),
  _doItOf("Copy your partner's moves like a mirror.", 'move', '🪞'),
  _doItOf(
    'Move across the room without your feet touching the floor twice in '
        'the same spot.',
    'move',
    '🦘',
  ),
  // make
  _doItOf('Teach the person next to you a secret handshake.', 'make', '🤝'),
  _doItOf('Trace your hand and turn it into an animal.', 'make', '🖐️'),
  _doItOf('Make up a sound for happy and a sound for sleepy.', 'make', '🔊'),
  _doItOf('Make a pattern: red, blue, red, blue…', 'make', '🔴'),
  _doItOf(
    'Make a face that shows exactly how you feel right now.',
    'make',
    '😊',
  ),
  _doItOf('Invent a brand-new dance move and give it a name.', 'make', '💃'),
  _doItOf(
    'Build a story together — each person adds one sentence.',
    'make',
    '📖',
  ),
  // ask
  _doItOf("Ask a friend: what's something you're really good at?", 'ask', '💬'),
  _doItOf('Ask someone what made them smile today.', 'ask', '😄'),
  _doItOf(
    "Find out your partner's favorite color and tell the room.",
    'ask',
    '🎨',
  ),
  _doItOf(
    'Ask someone to teach you one thing they know how to do.',
    'ask',
    '🧠',
  ),
  _doItOf(
    'Ask a grown-up what they wanted to be when they were little.',
    'ask',
    '👤',
  ),
  _doItOf(
    'Ask three people the same question and see if the answers match.',
    'ask',
    '❓',
  ),
  // help
  _doItOf('Help put every marker back with its own color.', 'help', '🧹'),
  _doItOf('Help stack the chairs neatly in one corner.', 'help', '🪑'),
  _doItOf('Help a friend find something they lost.', 'help', '🔦'),
  _doItOf(
    'Carry something to the other side of the room — together.',
    'help',
    '📦',
  ),
  _doItOf('Help make the reading corner tidy and cozy.', 'help', '📚'),
  _doItOf(
    'Show someone where something goes, then put it away together.',
    'help',
    '✅',
  ),
  // Potions + the garden (docs/VISION.md 2026-06-19) — the magic theme made
  // real + sensory. Tactile, in-proximity, take-turns, practice.
  _doItOf(
    'Mix a potion: petals, a leaf, and a little water. What does it smell like?',
    'make',
    '🧪',
  ),
  _doItOf(
    'Smell three different plants. Which is your favourite?',
    'find',
    '🌿',
  ),
  _doItOf('Water a plant gently and watch the soil drink it up.', 'help', '🪴'),
  _doItOf(
    'Take turns being the gardener — pass the watering can to a friend.',
    'help',
    '🌱',
  ),
  _doItOf(
    'Make a "garden soup" in a cup with grass, petals, and water.',
    'make',
    '🥣',
  ),
  _doItOf(
    'Find the softest leaf you can and feel it with your eyes shut.',
    'find',
    '🍃',
  ),
  _doItOf('Plant a seed and pat the soil down with your hands.', 'make', '🌰'),
  _doItOf(
    'Stand still in the garden — what three sounds can you hear?',
    'find',
    '👂',
  ),
  _doItOf(
    'Brew a "happy potion" in your mind — what colour and smell would it be?',
    'make',
    '✨',
  ),
];

// ── Question of the Day ───────────────────────────────────────────────────
// Open, answerable-many-ways prompts (docs/VISION.md 2026-06-19). Each is
// followed by a captured response (a drawing / sentence) into the child's
// Book. Kid-safe (4–12), no right answer — perspective + growth, "what will
// you invent…".
ContentItem _questionOf(String text) => ContentItem(
  kind: ContentKind.question,
  fingerprint: text.toLowerCase(),
  payload: {'text': text},
);

final List<ContentItem> _questionSeed = <ContentItem>[
  _questionOf('What would you invent if you could invent anything?'),
  _questionOf(
    'If you could talk to one animal, which one — and what would you ask?',
  ),
  _questionOf('What is something you are really good at?'),
  _questionOf('What made you laugh today?'),
  _questionOf('If you could have any superpower, what would it be and why?'),
  _questionOf('What does being a good friend look like?'),
  _questionOf('What is something new you want to learn?'),
  _questionOf('If you could build a whole world, what would be in it?'),
  _questionOf('What is the bravest thing you have ever done?'),
  _questionOf('What kind of person do you want to be when you grow up?'),
  _questionOf('What is something kind someone did for you?'),
  _questionOf('If today had a colour, what colour would it be?'),
  _questionOf('What is a problem you wish you could fix?'),
  _questionOf('What is your favourite place, and what makes it special?'),
  _questionOf('If you could give the whole world one gift, what would it be?'),
  _questionOf('What is something that makes you feel calm?'),
  _questionOf('What would you do with a whole day to yourself?'),
  _questionOf('Who is someone you look up to, and why?'),
  _questionOf('What is something you changed your mind about?'),
  _questionOf('If you could be any animal for a day, what would you be?'),
  // Reflective / presence questions (docs/VISION.md 2026-06-19) — "what is
  // happiness? is it here?" The deep end of the arc; answered by drawing OR
  // dialogue.
  _questionOf('What is happiness? Is it here, right now?'),
  _questionOf('What is one small thing that made today good?'),
  _questionOf('When do you feel most like yourself?'),
  _questionOf('What does it feel like to be kind to someone?'),
  _questionOf('If happiness were a place, what would it look like?'),
  _questionOf('What are you grateful for today?'),
];

// ── Quote of the Day ──────────────────────────────────────────────────────
// Short, kid-legible lines to sit with, answered with an interpretation.
ContentItem _quoteOf(String text, [String? author]) => ContentItem(
  kind: ContentKind.quote,
  fingerprint: text.toLowerCase(),
  payload: {'text': text, 'author': ?author},
);

final List<ContentItem> _quoteSeed = <ContentItem>[
  _quoteOf('The future belongs to the curious.'),
  _quoteOf('You are braver than you believe, and stronger than you seem.'),
  _quoteOf('Mistakes are proof that you are trying.'),
  _quoteOf('Kindness is a language everyone understands.'),
  _quoteOf('A little progress each day adds up to big things.'),
  _quoteOf('Be the friend you would like to have.'),
  _quoteOf('Every expert was once a beginner.'),
  _quoteOf('The best way to learn is to ask questions.'),
  _quoteOf('You don’t have to be perfect to be amazing.'),
  _quoteOf('Big things have small beginnings.'),
  _quoteOf('Helping one person might change the whole world for them.'),
  _quoteOf('Courage is trying, even when it’s hard.'),
  _quoteOf('Your imagination is a place you can always go.'),
  _quoteOf('Today is a chance to try something new.'),
  _quoteOf('Listening is a kind of magic.'),
  _quoteOf('Slow and steady can still win.'),
  _quoteOf('There is no wrong way to be yourself.'),
  _quoteOf('Wonder is the start of every great idea.'),
  _quoteOf('Small kindnesses make big differences.'),
  _quoteOf('What you practice, you become.'),
];
