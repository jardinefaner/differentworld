// A game arriving on a room's screen tells that room what it is about to
// play — through EITHER door.
//
// There were two: `cast()` (content-bank games) seeded the run-script cursor,
// and `castStage()` (the seven picture games, the world, the board, Now &
// Next) did not. So a cast Bingo briefed nobody, and nothing said so — the
// briefing was a property of one code path rather than of casting.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/facilitation/run_script_wire.dart';
import 'package:differentworld/features/games/cards/castable_card_games.dart';
import 'package:differentworld/features/games/cards/picture_card.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/live_session/cast_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  List<PictureCard> deck(int n) => [
    for (var i = 0; i < n; i++)
      PictureCard(
        id: 'c$i',
        label: 'thing $i',
        image: 'assets/decks/c$i.png',
        category: i.isEven ? 'food' : 'toys',
        deck: 'test',
      ),
  ];

  test('every scripted game briefs the room when it is cast', () {
    final bank = LocalContentBank.seeded();
    for (final g in liveGames.where((g) => g.howToPlay.isNotEmpty)) {
      // The content-bank door.
      if (g.seedsFromContentBank) {
        final wire = CastSession.freshWire(g.id, g.initialState(bank));
        expect(
          RunScriptWire.indexOf(CastSession.gameStateOf(wire)),
          0,
          reason: '${g.id} casts without telling the room what it is',
        );
      }
    }
  });

  test('the DECK door briefs too — it used to skip it entirely', () {
    for (final (def, seed) in castableCardGames) {
      if (def.howToPlay.isEmpty) continue;
      final wire = CastSession.freshWire(def.id, seed(deck(40)));
      expect(
        RunScriptWire.indexOf(CastSession.gameStateOf(wire)),
        0,
        reason: '${def.id} is cast from the deck and briefs nobody',
      );
      // And the round it will play is on the wire UNDER the briefing —
      // seeding adds a cursor, it never replaces the state. (The boards keep
      // `cells`, the card games keep `cards`, so the check is that nothing
      // the seed produced went missing.)
      final seeded = CastSession.gameStateOf(wire);
      for (final key in seed(deck(40)).keys) {
        expect(
          seeded.containsKey(key),
          isTrue,
          reason: '${def.id} lost "$key" to the seeding',
        );
      }
    }
  });

  test('a game with no script is never given a cursor', () {
    // The instruments — a signal, a clock, the live board. A briefing in
    // front of a countdown is the thing the ledger exists to prevent.
    for (final g in liveGames.where((g) => g.howToPlay.isEmpty)) {
      final wire = CastSession.freshWire(g.id, const {'any': 1});
      expect(
        RunScriptWire.indexOf(CastSession.gameStateOf(wire)),
        isNull,
        reason: '${g.id} has no script and should not brief',
      );
    }
  });

  test('an id this build has never heard of still casts', () {
    final wire = CastSession.freshWire('no-such-game', const {'a': 1});
    expect(CastSession.gameIdOf(wire), 'no-such-game');
    expect(CastSession.gameStateOf(wire)['a'], 1);
  });
}
