// Guess Who and Spot the Difference — the two cards on "Do together" that no
// test had ever mounted.
//
// Both are deck-seeded, and both were broken in ways a reducer test could not
// see. Guess Who's secret lived in `initialTally`, which the old wrapper
// skipped, so the answer was always square zero. Spot the Difference had no
// wrapper at all and read `ContentKind.picture` from the curated bank, which
// carries none — so on a fresh install it dealt an empty board and the room
// got "No cards yet". Both were fixed through the SEED; nothing ever checked
// that a person could play the result.
//
// So these play a round on the real screen: a board comes up, taps land, and
// the round reaches an ending a room can read.

import 'package:differentworld/features/games/cards/card_tile.dart';
import 'package:differentworld/features/games/cards/picture_card.dart';
import 'package:differentworld/features/games/cards/picture_deck_provider.dart';
import 'package:differentworld/features/games/games/classic_boards_screen.dart';
import 'package:differentworld/features/games/games/guess_who_game.dart';
import 'package:differentworld/features/games/games/spot_difference_game.dart';
import 'package:differentworld/features/games/round_wrap.dart';
import 'package:differentworld/features/live_session/shape_stage_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '_briefing.dart';

/// A deck, supplied rather than loaded.
///
/// The real `pictureDeckProvider` reads a manifest from the asset bundle, and
/// a bundle read only lands once per test FILE — the second mount sits on its
/// loading skeleton forever, which is why every other deck-seeded test here
/// holds exactly one `testWidgets`. Overriding is better anyway: the subject
/// is the seed and the screen, not the bundle.
final List<PictureCard> _deck = [
  for (var i = 0; i < 40; i++)
    PictureCard(
      id: 'c$i',
      label: 'Card $i',
      image: 'assets/decks/test/$i.png',
      category: ['animal', 'food', 'vehicle', 'tool'][i % 4],
      deck: 'test',
    ),
];

/// Mount a deck-seeded screen and get past the rules to the board.
///
/// **Bounded pumps, never `pumpAndSettle`.** The loading skeleton animates
/// with `repeat()`, so while anything is pending a frame is always scheduled
/// and `pumpAndSettle` spins until it times out.
Future<Finder> _toTheBoard(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [pictureDeckProvider.overrideWith((ref) async => _deck)],
      child: MaterialApp(home: screen),
    ),
  );
  for (
    var i = 0;
    i < 40 && find.byType(ShapeStageView).evaluate().isEmpty;
    i++
  ) {
    await tester.pump(const Duration(milliseconds: 100));
    if (i == 3) await skipTheBriefing(tester);
  }
  await _rest(tester);
  final grid = find.byType(ShapeStageView);
  expect(grid, findsOneWidget, reason: 'no board reached the screen at all');
  return grid;
}

/// Let the beats finish without waiting on a skeleton that never stops.
Future<void> _rest(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

List<Element> _cells(Finder grid) => find
    .descendant(of: grid, matching: find.byType(GestureDetector))
    .evaluate()
    .toList();

void main() {
  testWidgets('Guess Who deals faces, and knocking them out is undoable', (
    tester,
  ) async {
    const game = GuessWhoGame();
    final grid = await _toTheBoard(tester, const GuessWhoScreen(live: false));

    expect(
      find.descendant(of: grid, matching: find.byType(CardTile)),
      findsNWidgets(game.cols * game.rows),
      reason: 'the board came up empty — the deck never reached the seed',
    );
    // The COUNT, from the first frame. It used to appear only after somebody
    // had knocked a face out, so a room met twelve faces with no line beside
    // them and nothing saying what the game was measuring.
    final n = game.cols * game.rows;
    expect(find.text('$n left'), findsOneWidget, reason: 'nobody out yet');

    // Knock one out; the board counts what is left.
    await tester.tap(find.byWidget(_cells(grid).first.widget));
    await _rest(tester);
    expect(
      find.text('${n - 1} left'),
      findsOneWidget,
      reason: 'a knocked-out face is not counted, so the room cannot follow',
    );

    // And put it back — a room changes its mind.
    await tester.tap(find.byWidget(_cells(grid).first.widget));
    await _rest(tester);
    expect(
      find.text('$n left'),
      findsOneWidget,
      reason: 'knocking out is one-way — a room that misheard is stuck',
    );
  });

  testWidgets('Guess Who ends on the last face standing', (tester) async {
    const game = GuessWhoGame();
    final grid = await _toTheBoard(tester, const GuessWhoScreen(live: false));
    final n = game.cols * game.rows;

    // Knock out everyone but the last — whoever is left, the board knows
    // whether it was thinking of them.
    for (var i = 0; i < n - 1; i++) {
      await tester.tap(find.byWidget(_cells(grid)[i].widget));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await _rest(tester);
    expect(
      find.byType(RoundWrap),
      findsOneWidget,
      reason: 'one face left and no ending — the round just stops',
    );
  });

  testWidgets('Spot the Difference deals a board and can be won', (
    tester,
  ) async {
    const game = SpotDifferenceGame();
    final grid = await _toTheBoard(
      tester,
      const SpotDifferenceScreen(live: false),
    );

    final tiles = find.descendant(of: grid, matching: find.byType(CardTile));
    expect(
      tiles,
      findsWidgets,
      reason: 'the board came up empty — this shipped dead on arrival once',
    );

    // Tap every square until the odd one out is found. A wrong tap only
    // flashes, so this is what a room actually does.
    var won = false;
    for (var i = 0; i < game.cols * game.rows && !won; i++) {
      final cells = _cells(grid);
      if (i >= cells.length) break;
      await tester.tap(find.byWidget(cells[i].widget));
      await tester.pump(const Duration(milliseconds: 40));
      won = find.byType(RoundWrap).evaluate().isNotEmpty;
    }
    await _rest(tester);
    expect(
      won,
      isTrue,
      reason: 'no tap anywhere on the board ended the round',
    );
  });
}
