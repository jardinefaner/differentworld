/// Animal & nature ROLE CARDS (docs/ROLES_SMART_PRACTICE.md).
///
/// A role is a SMART daily practice in kid form: three HABITS (action verbs
/// the role practices), three ARTIFACTS (the proof it chooses to leave
/// behind — a drawing / photo / recording), and the trait it BUILDS.
/// "Today I am a Bee — I gather, I point the way, I stay busy."
///
/// Pure-Dart catalog for now. The same shape moves behind the content bank's
/// `ContentSource` (kind `role`) when it goes DB-backed — the activity never
/// changes, only where the cards come from (docs/CONTENT_BANK.md).
library;

/// One role card — a SEMANTIC_GRAPH noun the child can *become* for a day.
class RoleCard {
  const RoleCard({
    required this.emoji,
    required this.name,
    required this.habits,
    required this.artifacts,
    required this.builds,
  });

  final String emoji;
  final String name;

  /// Three action verbs the role practices every day (simple enough to
  /// become a habit).
  final List<String> habits;

  /// Three things the role chooses to leave behind — the artifact-capture
  /// contract a later slice reads (drawing / photo / recording is implied by
  /// the prompt text).
  final List<String> artifacts;

  /// The single trait this role grows.
  final String builds;

  /// De-dupe key (the content-bank fingerprint convention).
  String get fingerprint => name.toLowerCase();

  /// "a" / "an" for the "Today I am ___ {name}" header.
  String get article =>
      'aeiou'.contains(name.isEmpty ? '' : name[0].toLowerCase()) ? 'an' : 'a';
}

/// A themed deck of role cards. The role-card mechanic (3 habits, 3
/// artifacts, 1 trait) is theme-agnostic, so the catalog is a *set of
/// decks* — animals & nature, people & jobs, and (next) space, books,
/// games (docs/VISION.md dream #8). A kid can be a Bee one day and an
/// Astronaut the next.
class RoleDeck {
  const RoleDeck({
    required this.id,
    required this.name,
    required this.emoji,
    required this.tagline,
    required this.cards,
  });

  /// Stable id (the switcher key, and the future content-bank deck tag).
  final String id;

  /// Display name for the switcher chip ("Animals & Nature").
  final String name;

  /// A single glyph for the switcher chip.
  final String emoji;

  /// One-line subtitle shown under the screen title for this deck.
  final String tagline;

  final List<RoleCard> cards;
}

/// All shipped decks, in switcher order. Add a deck here to surface it.
const roleDecks = <RoleDeck>[_animalsDeck, _peopleDeck];

const _animalsDeck = RoleDeck(
  id: 'animals',
  name: 'Animals & Nature',
  emoji: '🦊',
  tagline: 'Be an animal for the day — pick a card',
  cards: _animalCards,
);

const _peopleDeck = RoleDeck(
  id: 'people',
  name: 'People & Jobs',
  emoji: '🧑‍🚀',
  tagline: 'Be someone who does big things — pick a card',
  cards: _peopleCards,
);

/// Back-compat alias — the original flat catalog name resolves to the
/// animals deck (kept so existing call-sites + tests don't break).
const List<RoleCard> roleCatalog = _animalCards;

/// The animals & nature deck — 23 roles curated for trait breadth so a kid
/// can be a *bee* one day and a *river* the next without it feeling like
/// the same card reskinned (docs/ROLES_SMART_PRACTICE.md §2).
const _animalCards = <RoleCard>[
  RoleCard(
    emoji: '🐜',
    name: 'Ant',
    habits: [
      'carry something heavy',
      'build a little tunnel',
      'team up with a friend',
    ],
    artifacts: [
      'tunnel-maze drawing',
      'photo of the heaviest thing I carried',
      'list of who I teamed up with',
    ],
    builds: 'teamwork',
  ),
  RoleCard(
    emoji: '🐝',
    name: 'Bee',
    habits: [
      'gather one thing at a time',
      'buzz a dance to point the way',
      "stay busy till it's done",
    ],
    artifacts: [
      'photo of all I gathered',
      'recording of my waggle-dance',
      'drawing of the flowers I visited',
    ],
    builds: 'diligence',
  ),
  RoleCard(
    emoji: '🦋',
    name: 'Butterfly',
    habits: ['change step by step', 'move gently', 'brighten the room'],
    artifacts: [
      'drawing of my four growing stages',
      'photo of my brightest colors',
      'recording of my soft flutter',
    ],
    builds: 'patience',
  ),
  RoleCard(
    emoji: '🕷️',
    name: 'Spider',
    habits: [
      'spin one careful strand',
      'wait quietly and watch',
      'try again if it breaks',
    ],
    artifacts: [
      'web-pattern drawing',
      'photo of the web I built',
      'note about the time I tried again',
    ],
    builds: 'persistence',
  ),
  RoleCard(
    emoji: '✨',
    name: 'Firefly',
    habits: [
      'make my own light',
      'flash a signal to a friend',
      'glow in the dark',
    ],
    artifacts: [
      'drawing of my glow at night',
      'recording of my blink-signal',
      'note about when I shined',
    ],
    builds: 'confidence',
  ),
  RoleCard(
    emoji: '🐬',
    name: 'Dolphin',
    habits: ['check on a friend', 'call out kindly', 'leap with joy'],
    artifacts: [
      'drawing of my pod',
      'photo of me helping a buddy',
      'a friendly whistle I record',
    ],
    builds: 'kindness',
  ),
  RoleCard(
    emoji: '🐙',
    name: 'Octopus',
    habits: ['try a new way', 'change and adapt', 'reach with many arms'],
    artifacts: [
      'drawing of my puzzle + how I solved it',
      'photo of what I fixed',
      'list of 3 ways I tried',
    ],
    builds: 'problem-solving',
  ),
  RoleCard(
    emoji: '🐳',
    name: 'Whale',
    habits: ['take a deep breath', 'sing my song', 'move gently and big'],
    artifacts: [
      'drawing of my deep calm breath',
      'a whale song I record',
      'photo of my calm face',
    ],
    builds: 'calm',
  ),
  RoleCard(
    emoji: '🦀',
    name: 'Crab',
    habits: ['tidy my space', 'carry my home', 'hold on tight'],
    artifacts: [
      'photo of my tidy table',
      'drawing of my shell home',
      'list of what I put away',
    ],
    builds: 'responsibility',
  ),
  RoleCard(
    emoji: '🦒',
    name: 'Giraffe',
    habits: ['stand tall', 'look far', 'reach high'],
    artifacts: [
      'photo on tiptoes looking far',
      '"tall as a giraffe" self-drawing',
      'note naming one far-away thing I spotted',
    ],
    builds: 'confidence',
  ),
  RoleCard(
    emoji: '🦊',
    name: 'Fox',
    habits: ['look closely', 'listen quietly', 'figure it out'],
    artifacts: [
      'photo of a tricky thing I solved',
      '"sneaky-clever plan" drawing',
      'note with one good idea I had',
    ],
    builds: 'problem-solving',
  ),
  RoleCard(
    emoji: '🐘',
    name: 'Elephant',
    habits: ['stay gentle', 'help the little ones', 'remember a friend'],
    artifacts: [
      'photo of me helping a younger friend',
      'drawing of my herd',
      'note saying one kind thing I did',
    ],
    builds: 'kindness',
  ),
  RoleCard(
    emoji: '🐰',
    name: 'Rabbit',
    habits: ['listen with big ears', 'hold very still', 'notice tiny things'],
    artifacts: [
      'a sound I recorded after listening',
      'drawing of one tiny thing most would miss',
      'note about something small I noticed',
    ],
    builds: 'focus',
  ),
  RoleCard(
    emoji: '🐺',
    name: 'Wolf',
    habits: ['move with the pack', 'take turns', 'follow and lead'],
    artifacts: [
      'photo of my pack working together',
      'a "howl" recorded with my team',
      'note naming who I teamed up with',
    ],
    builds: 'teamwork',
  ),
  RoleCard(
    emoji: '🦉',
    name: 'Owl',
    habits: ['listen closely', 'turn to look', 'sit still and watch'],
    artifacts: [
      'drawing of the quietest thing I noticed',
      'recording of a sound only I could hear',
      'list of 3 things I spotted by waiting',
    ],
    builds: 'focus',
  ),
  RoleCard(
    emoji: '🐧',
    name: 'Penguin',
    habits: ['huddle close', 'take turns', 'waddle together'],
    artifacts: [
      'drawing of our huddle keeping warm',
      'recording of our group waddle',
      'written thank-you to someone who took a turn',
    ],
    builds: 'teamwork',
  ),
  RoleCard(
    emoji: '🐦',
    name: 'Hummingbird',
    habits: ['visit each thing', 'hover and look close', 'taste something new'],
    artifacts: [
      'drawing of the most colorful thing I found',
      'photo of a new thing I tried',
      'list of every spot I visited',
    ],
    builds: 'curiosity',
  ),
  RoleCard(
    emoji: '🐦‍⬛',
    name: 'Crow',
    habits: ['solve a puzzle', 'make a tool', 'remember a face'],
    artifacts: [
      'drawing of the tool I built',
      'photo of the puzzle I solved',
      'name of a friend I remembered to greet',
    ],
    builds: 'cleverness',
  ),
  RoleCard(
    emoji: '🌳',
    name: 'Oak Tree',
    habits: ['stand firm', 'grow a little', 'give shade'],
    artifacts: [
      'drawing of my tree with one new ring',
      'photo of someone I sheltered',
      'note naming one thing I grew at',
    ],
    builds: 'patience',
  ),
  RoleCard(
    emoji: '🌻',
    name: 'Sunflower',
    habits: ['turn toward the light', 'open wide', 'stand tall'],
    artifacts: [
      'photo of the sunniest spot I found',
      'drawing of my face turned toward something good',
      'a recorded cheer for a friend',
    ],
    builds: 'optimism',
  ),
  RoleCard(
    emoji: '🌊',
    name: 'River',
    habits: ['keep flowing', 'go around the rock', 'carry it forward'],
    artifacts: [
      'recorded "shhhh" flowing sound',
      'drawing of my path bending around a rock',
      'note about one hard thing I kept past',
    ],
    builds: 'perseverance',
  ),
  RoleCard(
    emoji: '🌱',
    name: 'Seed',
    habits: ['wait in the dark', 'soak it up', 'push up a sprout'],
    artifacts: [
      'drawing of my first sprout',
      'photo of one new thing I tried for the first time',
      "note naming what I'm growing into",
    ],
    builds: 'courage',
  ),
  RoleCard(
    emoji: '🍄',
    name: 'Mushroom',
    habits: ['connect underground', 'share what I have', 'clean up & recycle'],
    artifacts: [
      'drawing of my hidden threads reaching friends',
      'photo of something I shared or tidied',
      'a recorded "here you go" passing help',
    ],
    builds: 'connection',
  ),
];

/// The people & jobs deck — 12 roles, one per trait, so a kid can try on a
/// way of working in the world. Same shape as the animal deck; profession
/// glyphs as the "icon" (docs/VISION.md dream #8).
const _peopleCards = <RoleCard>[
  RoleCard(
    emoji: '🧑‍🚀',
    name: 'Astronaut',
    habits: [
      'explore somewhere new',
      'check every step',
      'stay brave in the dark',
    ],
    artifacts: [
      'drawing of the planet I explored',
      'photo of the bravest thing I tried',
      'a launch countdown I recorded',
    ],
    builds: 'courage',
  ),
  RoleCard(
    emoji: '🧑‍🔬',
    name: 'Scientist',
    habits: ['ask "what if?"', 'test my idea', 'write down what I saw'],
    artifacts: [
      'drawing of my experiment',
      'note about what surprised me',
      'photo of the thing I tested',
    ],
    builds: 'curiosity',
  ),
  RoleCard(
    emoji: '👩‍⚕️',
    name: 'Doctor',
    habits: ['listen first', 'be gentle', 'help it feel better'],
    artifacts: [
      'note naming who I helped',
      'drawing of my care kit',
      'a get-well message I recorded',
    ],
    builds: 'kindness',
  ),
  RoleCard(
    emoji: '🧑‍🚒',
    name: 'Firefighter',
    habits: ['stay calm in a rush', 'help fast', 'never leave a friend behind'],
    artifacts: [
      'photo of me helping fast',
      'drawing of my brave plan',
      'note about staying calm',
    ],
    builds: 'calm',
  ),
  RoleCard(
    emoji: '👷',
    name: 'Builder',
    habits: ['measure before I cut', 'stack it strong', 'finish what I start'],
    artifacts: [
      'photo of what I built',
      'drawing of my blueprint',
      'note about the hard part I finished',
    ],
    builds: 'perseverance',
  ),
  RoleCard(
    emoji: '👩‍🏫',
    name: 'Teacher',
    habits: ['explain it kindly', 'wait for everyone', 'cheer a friend on'],
    artifacts: [
      'note about what I taught a friend',
      'drawing of my lesson',
      'a cheer I recorded',
    ],
    builds: 'patience',
  ),
  RoleCard(
    emoji: '🧑‍🌾',
    name: 'Farmer',
    habits: ['tend it every day', 'wait for it to grow', 'share the harvest'],
    artifacts: [
      'photo of what I cared for',
      'drawing of my garden',
      'note about what I shared',
    ],
    builds: 'responsibility',
  ),
  RoleCard(
    emoji: '🧑‍🎨',
    name: 'Artist',
    habits: ['see colors everywhere', 'try it my own way', 'share what I made'],
    artifacts: [
      'photo of my art',
      'a drawing only I would make',
      'note about my idea',
    ],
    builds: 'creativity',
  ),
  RoleCard(
    emoji: '🕵️',
    name: 'Detective',
    habits: ['notice the tiny clue', 'ask good questions', 'piece it together'],
    artifacts: [
      'drawing of the clue I found',
      'note with my biggest question',
      'photo of what I figured out',
    ],
    builds: 'focus',
  ),
  RoleCard(
    emoji: '👨‍🍳',
    name: 'Chef',
    habits: ['follow the recipe', 'taste and adjust', 'serve with care'],
    artifacts: [
      'drawing of my recipe',
      'photo of what I made',
      'note naming who I served',
    ],
    builds: 'generosity',
  ),
  RoleCard(
    emoji: '🧑‍🔧',
    name: 'Inventor',
    habits: ['find what is broken', 'try a new fix', 'make it better'],
    artifacts: [
      'drawing of my invention',
      'note of 3 fixes I tried',
      'photo of what I improved',
    ],
    builds: 'problem-solving',
  ),
  RoleCard(
    emoji: '🎻',
    name: 'Musician',
    habits: ['practice a little daily', 'keep the beat', 'play together'],
    artifacts: [
      'a tune I recorded',
      'drawing of my instrument',
      'note about what I practiced',
    ],
    builds: 'practice',
  ),
];
