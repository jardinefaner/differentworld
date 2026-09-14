import 'dart:async';

import 'package:differentworld/features/activity_runtime/activity_deck.dart';
import 'package:differentworld/features/omnibox/omnibox_entries.dart';
import 'package:go_router/go_router.dart';

/// One omnibox entry per card in the Do-together library.
///
/// The catalog hand-writes entries for a dozen surfaces, and before this the
/// forty-odd games were not among them: a teacher who typed "bingo" or
/// "connect four" into the bar found nothing, and the only way to a game was
/// the deck. Generated from the SAME list the library renders, so a card
/// added to the deck is searchable the same moment — the discovery-drift
/// class CLAUDE.md's four-places rule exists to stop.
///
/// Routes in [alreadyListed] keep their hand-written entry (richer keywords,
/// a settled id); the generator skips them rather than doubling them.
List<OmniboxEntry> deckEntries({required bool camera}) {
  final cards = [...breakDeck(camera: camera), ...presentDeck];
  return [
    for (final card in cards)
      if (!alreadyListed.contains(card.route))
        OmniboxEntry(
          id: 'page.deck.${_slug(card.route)}',
          label: card.title,
          subtitle: card.tagline,
          category: OmniboxCategory.activity,
          icon: card.icon,
          heroColor: card.color,
          keywords: [
            card.title.toLowerCase(),
            ..._words(card.title),
            ..._words(card.tagline),
            'game',
            'play',
            'brain break',
            'do together',
            if (card.lane == DeckLane.screen) ...['board', 'screen', 'tv'],
            ..._extraKeywords[card.route] ?? const <String>[],
          ],
          onSelect: (ctx, _) => unawaited(ctx.push(card.route)),
        ),
  ];
}

/// Deck routes the catalog already lists by hand. Keep in step with
/// omnibox_catalog.dart — the test in deck_omnibox_test asserts every deck
/// route is listed exactly once, so a drift either way fails the build.
const Set<String> alreadyListed = <String>{
  '/activity/do-it',
  '/present/name-it',
  '/present/odd-one-out',
  '/present/whats-missing',
  '/present/memory-match',
  '/present/now-next',
  '/present/poll',
  '/present/picker',
  '/present/cues',
  '/cast',
  '/live-board',
};

/// What people actually call a thing, beyond its title — the words a
/// substitute types when they half-remember a game.
const Map<String, List<String>> _extraKeywords = <String, List<String>>{
  '/activity/this-or-that': ['would you rather', 'pick one', 'choose'],
  '/activity/as-if': ['act', 'drama', 'voices', 'improv'],
  '/activity/starts-with': ['letters', 'alphabet', 'categories', 'name things'],
  '/activity/math-game': ['maths', 'numbers', 'sums', 'quiz'],
  '/activity/math': ['maths', 'number talk', 'ways to make'],
  '/activity/roles': ['animals', 'be an animal', 'character', 'costume'],
  '/activity/pattern': ['tiles', 'repeat', 'kaleidoscope', 'symmetry'],
  '/activity/discussions': [
    'talk',
    'discussion',
    'circle time',
    'conversation',
  ],
  '/activity/bingo': ['cards', 'call', 'line', 'four in a row'],
  '/activity/battleship': ['ships', 'hit', 'miss', 'grid', 'coordinates'],
  '/activity/guess-who': ['faces', 'yes or no', 'questions', 'eliminate'],
  '/activity/connect-four': ['discs', 'drop', 'four in a row', 'counters'],
  '/activity/lights-out': ['lights', 'puzzle', 'switch', 'toggle'],
  '/activity/minesweeper': ['mines', 'bombs', 'flags', 'puzzle'],
  '/activity/hangman': ['guess the word', 'letters', 'spelling'],
  '/activity/four-corners': ['corners', 'move', 'stand', 'vote with feet'],
  '/activity/word-search': ['find words', 'letters', 'puzzle', 'spelling'],
  '/activity/boggle': ['letters', 'make words', 'timer', 'spelling'],
  '/activity/whack-a-mole': ['mole', 'tap', 'fast', 'reflex', 'arcade'],
  '/activity/simon': ['simon says', 'pattern', 'memory', 'colours', 'sequence'],
  '/activity/scavenger': ['hunt', 'find', 'outside', 'nature', 'list'],
  '/activity/wordle': ['five letters', 'guess the word', 'spelling'],
  '/activity/scattergories': ['categories', 'letter', 'list', 'name things'],
  '/activity/crossword': ['clues', 'across', 'down', 'puzzle', 'spelling'],
  '/activity/snakes-ladders': ['dice', 'roll', 'race', 'board game', 'ladders'],
  '/activity/dots-boxes': ['dots', 'lines', 'boxes', 'pen and paper'],
  '/activity/spot-difference': ['spot it', 'different', 'compare', 'pictures'],
  '/activity/riddles': ['riddle', 'brain teaser', 'guess'],
  '/activity/grid-reveal': ['reveal', 'hidden picture', 'guess the picture'],
  '/activity/breathe': ['breathe', 'calm', 'mindful', 'relax', 'quiet'],
  '/activity/fact-or-fib': ['true or false', 'facts', 'trivia'],
  '/activity/story': ['story', 'once upon a time', 'imagination', 'twist'],
  '/activity/rhyme-time': ['rhymes', 'rhyming', 'poetry', 'words'],
  '/activity/fill-blank': ['mad libs', 'silly story', 'blanks', 'words'],
  '/activity/letters': ['write', 'notes', 'pen pal', 'kind words'],
  '/activity/penny': ['thoughts', 'share', 'question', 'pennies', 'count'],
  '/activity/potions': ['recipe', 'brew', 'mix', 'garden', 'make believe'],
  '/activity/charades': ['act it out', 'mime', 'no words', 'guess'],
  '/activity/photo': ['camera', 'photos', 'pictures', 'studio'],
};

String _slug(String route) =>
    route.replaceFirst(RegExp('^/'), '').replaceAll('/', '.');

Iterable<String> _words(String text) => text
    .toLowerCase()
    .split(RegExp('[^a-z0-9]+'))
    .where((w) => w.length > 2)
    .toSet();
