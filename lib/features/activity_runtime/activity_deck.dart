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
