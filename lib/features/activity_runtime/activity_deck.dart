import 'package:differentworld/app/design_tokens.dart';
import 'package:flutter/material.dart';

/// One card in the activity library.
///
/// `_PresentCard` and `_BreakCard` were the SAME five fields in two files, and
/// the two hubs they fed were split on a line that turns out not to exist:
/// every item in both is a route, both render the same tile, and Present linked
/// to Brain Breaks as though it were a subcategory of itself. The only real
/// difference was which one happened to offer casting — an accident of the two
/// growing separately, not a capability boundary.
class DeckCard {
  const DeckCard({
    required this.title,
    required this.tagline,
    required this.icon,
    required this.color,
    required this.route,
    required this.lane,
  });

  final String title;
  final String tagline;
  final IconData icon;
  final Color color;
  final String route;

  /// Which shelf of the library this sits on.
  final DeckLane lane;
}

/// How the library groups itself.
///
/// The grouping is by WHAT THE THING IS, not by which hub grew it. A staffer
/// deciding what to do next is asking "do I want the room looking at a screen,
/// do I need ninety seconds of reset, or is this part of the daily rhythm" —
/// they are never asking "was this built as a Present surface".
/// **Declaration order is render order**, and resets lead deliberately. A
/// staffer opening this mid-afternoon needs ninety seconds of reset far more
/// often than they need to set something up on the TV, and the screen lane's
/// anchor — "Cast to a screen" — already lives in the top chrome on every
/// route. Leading with the screen lane would put the most-reached-for cards
/// below the fold to make room for the most deliberate ones.
enum DeckLane {
  /// Ninety seconds of reset, done together, screen optional.
  reset,

  /// The room looks AT it: a board, a picture, a poll on the TV.
  screen,

  /// The day's own shape — today's question, the recap, the spellbook.
  rhythm,
}

extension DeckLaneLabel on DeckLane {
  String get label => switch (this) {
    DeckLane.screen => "On the room's screen",
    DeckLane.reset => 'Quick resets',
    DeckLane.rhythm => "The day's rhythm",
  };
}

/// The room-facing deck, exposed so the ONE activity library can render it
/// alongside the resets instead of hiding it behind a second hub. The two
/// hubs were split on a line that does not exist: same card shape, same
/// tile, every item a route.
const List<DeckCard> presentDeck = <DeckCard>[
  // The app remote (docs/LIVE_SESSIONS.md "the cast model") — make a screen a
  // clean display and pick / switch / drive it all from this phone.
  DeckCard(
    title: 'Cast to a screen',
    tagline: 'Phone is the remote — pick, switch, control',
    icon: Icons.cast,
    color: ActivityPalette.tealDeep,
    lane: DeckLane.screen,
    route: '/cast',
  ),
  DeckCard(
    title: 'Live Board',
    tagline: 'Type a word, spell for a kid — live on every screen',
    icon: Icons.draw_outlined,
    color: ActivityPalette.cyan,
    lane: DeckLane.screen,
    route: '/live-board',
  ),
  DeckCard(
    title: 'Now & Next',
    tagline: "What's on now — and next",
    icon: Icons.calendar_view_day_outlined,
    color: ActivityPalette.teal,
    lane: DeckLane.screen,
    route: '/present/now-next',
  ),
  DeckCard(
    title: 'Name It',
    tagline: 'Picture up — say the word',
    icon: Icons.style_outlined,
    color: ActivityPalette.purple,
    lane: DeckLane.screen,
    route: '/present/name-it',
  ),
  DeckCard(
    title: 'Odd One Out',
    tagline: 'Three match, one doesn’t — spot it',
    icon: Icons.category_outlined,
    color: ActivityPalette.red,
    lane: DeckLane.screen,
    route: '/present/odd-one-out',
  ),
  DeckCard(
    title: "What's Missing",
    tagline: 'Study the set — what vanished?',
    icon: Icons.visibility_off_outlined,
    color: ActivityPalette.pink,
    lane: DeckLane.screen,
    route: '/present/whats-missing',
  ),
  DeckCard(
    title: 'Memory',
    tagline: 'Match the pairs — tap two to flip',
    icon: Icons.grid_view_rounded,
    color: ActivityPalette.indigo,
    lane: DeckLane.screen,
    route: '/present/memory-match',
  ),
  DeckCard(
    title: 'Quick Poll',
    tagline: 'Vote together, see the winner',
    icon: Icons.how_to_vote_outlined,
    color: ActivityPalette.indigo,
    lane: DeckLane.screen,
    route: '/present/poll',
  ),
  DeckCard(
    title: 'Spotlight',
    tagline: 'Fair turns — spin for a name',
    icon: Icons.star_outline,
    color: ActivityPalette.amber,
    lane: DeckLane.screen,
    route: '/present/picker',
  ),
  DeckCard(
    title: 'Signals',
    tagline: 'Eyes up · Clean up · Breathe',
    icon: Icons.campaign_outlined,
    color: ActivityPalette.blue,
    lane: DeckLane.screen,
    route: '/present/cues',
  ),
];

/// The reset + classic cards — everything a room can play from the library
/// that is not a room-screen presentable (those are [presentDeck]).
///
/// A FUNCTION of the platform rather than a constant: the camera-backed
/// cards only exist where there is a usable camera (docs/PLATFORM_RUBRIC.md
/// P1 — no dead "take a photo" buttons). Lives here, not in the screen,
/// because two surfaces read it: the library grid and the omnibox, which
/// generates one search entry per card so a teacher who types "bingo"
/// finds Bingo. Only Do It was searchable before — forty games were not.
List<DeckCard> breakDeck({required bool camera}) => <DeckCard>[
  // "Do It" leads — the one card that sends the room OFF the screen to do
  // a real thing, and keeps a record of it (docs/VISION.md 2026-06-18).
  const DeckCard(
    title: 'Do It',
    tagline: 'A real thing to go do',
    icon: Icons.directions_run_outlined,
    color: ActivityPalette.green,
    lane: DeckLane.reset,
    route: '/activity/do-it',
  ),
  const DeckCard(
    title: 'This or That',
    tagline: 'This or that?',
    icon: Icons.swap_horiz,
    color: ActivityPalette.pink,
    lane: DeckLane.reset,
    route: '/activity/this-or-that',
  ),
  const DeckCard(
    title: 'Say It As If',
    tagline: 'Say it as if…',
    icon: Icons.theater_comedy,
    color: ActivityPalette.purple,
    lane: DeckLane.reset,
    route: '/activity/as-if',
  ),
  const DeckCard(
    title: 'Beat the Letter',
    tagline: 'Words that start with…',
    icon: Icons.abc,
    color: ActivityPalette.teal,
    lane: DeckLane.reset,
    route: '/activity/starts-with',
  ),
  const DeckCard(
    title: 'Math Game',
    tagline: 'One question at a time',
    icon: Icons.quiz_outlined,
    color: ActivityPalette.blue,
    lane: DeckLane.reset,
    route: '/activity/math-game',
  ),
  const DeckCard(
    title: 'Many Paths',
    tagline: 'How many ways to a number?',
    icon: Icons.calculate,
    color: ActivityPalette.indigo,
    lane: DeckLane.reset,
    route: '/activity/math',
  ),
  // Camera-dependent: hidden where there's no in-app camera
  // (docs/PLATFORM_RUBRIC.md P1 — no dead "take a photo" buttons).
  if (camera)
    const DeckCard(
      title: 'Photo Studio',
      tagline: 'Capture the moment',
      icon: Icons.photo_camera,
      color: ActivityPalette.amber,
      lane: DeckLane.reset,
      route: '/activity/photo',
    ),
  const DeckCard(
    title: 'Role Cards',
    tagline: 'Be an animal — or an astronaut',
    icon: Icons.pets,
    color: ActivityPalette.green,
    lane: DeckLane.reset,
    route: '/activity/roles',
  ),
  const DeckCard(
    title: 'Make a Pattern',
    tagline: 'Snap a tile, watch it repeat',
    icon: Icons.grid_on,
    color: ActivityPalette.deepPurple,
    lane: DeckLane.reset,
    route: '/activity/pattern',
  ),
  const DeckCard(
    title: 'Group Talk',
    tagline: 'Discuss — by topic & age',
    icon: Icons.forum_outlined,
    color: ActivityPalette.cyan,
    lane: DeckLane.reset,
    route: '/activity/discussions',
  ),
  // The classics. Nothing to teach — four generations already know the
  // rules, which is the same reason the stages stopped narrating themselves.
  const DeckCard(
    title: 'Bingo',
    tagline: 'The board calls — cross them off',
    icon: Icons.grid_view_rounded,
    color: ActivityPalette.amber,
    lane: DeckLane.screen,
    route: '/activity/bingo',
  ),
  const DeckCard(
    title: 'Battleship',
    tagline: 'Call a square — hit or miss',
    icon: Icons.sailing_outlined,
    color: ActivityPalette.blue,
    lane: DeckLane.screen,
    route: '/activity/battleship',
  ),
  const DeckCard(
    title: 'Guess Who',
    tagline: 'Ask, rule them out, one left',
    icon: Icons.face_outlined,
    color: ActivityPalette.purple,
    lane: DeckLane.screen,
    route: '/activity/guess-who',
  ),
  const DeckCard(
    title: 'Connect Four',
    tagline: 'Four in a line wins',
    icon: Icons.circle_outlined,
    color: ActivityPalette.red,
    lane: DeckLane.screen,
    route: '/activity/connect-four',
  ),
  const DeckCard(
    title: 'Lights Out',
    tagline: 'Tap one, its neighbours flip',
    icon: Icons.lightbulb_outline,
    color: ActivityPalette.yellow,
    lane: DeckLane.screen,
    route: '/activity/lights-out',
  ),
  const DeckCard(
    title: 'Minesweeper',
    tagline: 'The number says how many are near',
    icon: Icons.flag_outlined,
    color: ActivityPalette.brown,
    lane: DeckLane.screen,
    route: '/activity/minesweeper',
  ),
  const DeckCard(
    title: 'Hangman',
    tagline: 'Guess the word, letter by letter',
    icon: Icons.abc,
    color: ActivityPalette.teal,
    lane: DeckLane.screen,
    route: '/activity/hangman',
  ),
  const DeckCard(
    title: 'Four Corners',
    tagline: 'Everyone goes and stands in one',
    icon: Icons.crop_square,
    color: ActivityPalette.green,
    lane: DeckLane.screen,
    route: '/activity/four-corners',
  ),
  const DeckCard(
    title: 'Word Search',
    tagline: 'Across and down',
    icon: Icons.text_fields,
    color: ActivityPalette.green,
    lane: DeckLane.screen,
    route: '/activity/word-search',
  ),
  const DeckCard(
    title: 'Boggle',
    tagline: 'Sixteen letters, make words',
    icon: Icons.apps,
    color: ActivityPalette.red,
    lane: DeckLane.screen,
    route: '/activity/boggle',
  ),
  const DeckCard(
    title: 'Whack-a-Mole',
    tagline: 'Quick — before it moves',
    icon: Icons.touch_app_outlined,
    color: ActivityPalette.amber,
    lane: DeckLane.screen,
    route: '/activity/whack-a-mole',
  ),
  const DeckCard(
    title: 'Simon',
    tagline: 'Watch, then say it back',
    icon: Icons.animation,
    color: ActivityPalette.deepPurple,
    lane: DeckLane.screen,
    route: '/activity/simon',
  ),
  const DeckCard(
    title: 'Scavenger Hunt',
    tagline: 'Find them outside',
    icon: Icons.travel_explore,
    color: ActivityPalette.teal,
    lane: DeckLane.screen,
    route: '/activity/scavenger',
  ),
  const DeckCard(
    title: 'Wordle',
    tagline: 'Six goes at five letters',
    icon: Icons.grid_on,
    color: ActivityPalette.green,
    lane: DeckLane.screen,
    route: '/activity/wordle',
  ),
  const DeckCard(
    title: 'Scattergories',
    tagline: 'One letter, six categories',
    icon: Icons.category,
    color: ActivityPalette.red,
    lane: DeckLane.screen,
    route: '/activity/scattergories',
  ),
  const DeckCard(
    title: 'Crossword',
    tagline: 'Across and down, with clues',
    icon: Icons.border_all,
    color: ActivityPalette.blue,
    lane: DeckLane.screen,
    route: '/activity/crossword',
  ),
  const DeckCard(
    title: 'Snakes & Ladders',
    tagline: 'Roll, climb, slide',
    icon: Icons.stairs,
    color: ActivityPalette.teal,
    lane: DeckLane.screen,
    route: '/activity/snakes-ladders',
  ),
  const DeckCard(
    title: 'Dots & Boxes',
    tagline: 'Close a box, go again',
    icon: Icons.border_outer,
    color: ActivityPalette.deepPurple,
    lane: DeckLane.screen,
    route: '/activity/dots-boxes',
  ),
  const DeckCard(
    title: 'Spot the Difference',
    tagline: 'One thing changed',
    icon: Icons.compare,
    color: ActivityPalette.pink,
    lane: DeckLane.screen,
    route: '/activity/spot-difference',
  ),
  const DeckCard(
    title: 'Riddle Me This',
    tagline: 'Guess the answer',
    icon: Icons.lightbulb_outline,
    color: ActivityPalette.yellow,
    lane: DeckLane.reset,
    route: '/activity/riddles',
  ),
  const DeckCard(
    title: 'Reveal the Picture',
    tagline: 'Call a square, guess the picture',
    icon: Icons.grid_on,
    color: ActivityPalette.cyan,
    lane: DeckLane.reset,
    route: '/activity/grid-reveal',
  ),
  const DeckCard(
    title: 'Mindful Minute',
    tagline: 'Breathe together',
    icon: Icons.spa_outlined,
    color: ActivityPalette.teal,
    lane: DeckLane.reset,
    route: '/activity/breathe',
  ),
  const DeckCard(
    title: 'Fact or Fib',
    tagline: 'True, or made up?',
    icon: Icons.fact_check_outlined,
    color: ActivityPalette.deepPurple,
    lane: DeckLane.reset,
    route: '/activity/fact-or-fib',
  ),
  const DeckCard(
    title: 'Story Starters',
    tagline: 'Build a story together',
    icon: Icons.auto_stories_outlined,
    color: ActivityPalette.indigo,
    lane: DeckLane.reset,
    route: '/activity/story',
  ),
  const DeckCard(
    title: 'Rhyme Time',
    tagline: 'How many rhymes?',
    icon: Icons.music_note_outlined,
    color: ActivityPalette.pink,
    lane: DeckLane.reset,
    route: '/activity/rhyme-time',
  ),
  const DeckCard(
    title: 'Fill in the Blank',
    tagline: 'Silly words → read it aloud',
    icon: Icons.edit_note_outlined,
    color: ActivityPalette.amber,
    lane: DeckLane.reset,
    route: '/activity/fill-blank',
  ),
  const DeckCard(
    title: 'Letters',
    tagline: 'Write to a friend',
    icon: Icons.mail_outline,
    color: ActivityPalette.pink,
    lane: DeckLane.reset,
    route: '/activity/letters',
  ),
  const DeckCard(
    title: 'Penny for a Thought',
    tagline: 'Share a thought, count a penny',
    icon: Icons.toll_outlined,
    color: ActivityPalette.amber,
    lane: DeckLane.reset,
    route: '/activity/penny',
  ),
  const DeckCard(
    title: 'Potions',
    tagline: 'Gather, stir, name your potion',
    icon: Icons.science_outlined,
    color: ActivityPalette.green,
    lane: DeckLane.reset,
    route: '/activity/potions',
  ),
  // One device: the phone is the actor's card, the room guesses. The
  // two-device session (/live/charades) is still one long-press away.
  const DeckCard(
    title: 'Charades',
    tagline: 'Act it out — no words',
    icon: Icons.theater_comedy_outlined,
    color: ActivityPalette.purple,
    lane: DeckLane.reset,
    route: '/activity/charades',
  ),
];
