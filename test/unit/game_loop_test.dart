// Every classic must be PLAYABLE: a board you can act on that reaches an
// ending. Before this, `GridBoard.done` existed, `GameScaffold` drew the
// "Round complete!" beat from it, and nothing in the codebase ever set it —
// so nineteen games dealt a board, took taps forever, and could not be won,
// lost or finished.
//
// These are the tests that would have caught that.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/games/battleship_game.dart';
import 'package:differentworld/features/games/games/bingo_game.dart';
import 'package:differentworld/features/games/games/dots_boxes_game.dart';
import 'package:differentworld/features/games/games/guess_who_game.dart';
import 'package:differentworld/features/games/games/lights_out_game.dart';
import 'package:differentworld/features/games/games/scattergories_game.dart';
import 'package:differentworld/features/games/games/scavenger_bingo_game.dart';
import 'package:differentworld/features/games/games/simon_game.dart';
import 'package:differentworld/features/games/games/snakes_ladders_game.dart';
import 'package:differentworld/features/games/games/whack_a_mole_game.dart';
import 'package:differentworld/features/games/games/word_search_game.dart';
import 'package:differentworld/features/games/games/wordle_game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A FRESH bank per game, because that is what the app does: every
  // GameRunner builds its own ContentEngine, so one game's deal never eats
  // another's. (Sharing one made Guess Who look permanently empty — it took
  // the pictures Bingo had already consumed.)
  //
  // Seeded WITH pictures, because the picture games are seeded from the
  // bundled decks in the app (`DataSeededGame` + `pictureDeckProvider`), not
  // from the curated text bank, which carries no `picture` items at all.
  LocalContentBank bank() => LocalContentBank.seededWith([
    ...curatedSeeds,
    for (var i = 0; i < 40; i++)
      ContentItem(
        kind: ContentKind.picture,
        fingerprint: 'pic$i',
        payload: {'image': 'assets/decks/pic$i.png', 'label': 'Card $i'},
      ),
  ]);

  /// Every grid game in the registry, so a new one can't skip the bar.
  List<GridGame> gridGames() => [
    for (final def in liveGames)
      if (def is GridGame) def,
  ];

  group('every grid game can end', () {
    // The ledger. `outcomeFor` cannot be detected by reflection, so it is
    // explicit: every grid game is either KNOWN to end, or KNOWN to be
    // deliberately endless, and a game in neither list fails the build.
    const hasLoop = <String>{
      'whack-a-mole',
      'boggle',
      'simon',
      'bingo',
      'lights-out',
      'minesweeper',
      'guess-who',
      'connect-four',
      'dots-boxes',
      'spot-difference',
      'battleship',
      'snakes-ladders',
      'scavenger',
      'hangman',
      'wordle',
      'word-search',
      'scattergories',
      'crossword',
    };

    // Endless ON PURPOSE, with the reason. This list should stay very short;
    // "it has no ending" is almost always a gap, not a design.
    const noEnding = <String, String>{
      'four-corners':
          'The board is the ROOM — everyone stands in a corner. Nobody wins, '
          'and inventing a winner would change what the activity is.',
    };

    test('the registry actually has grid games (the check can fail)', () {
      expect(gridGames(), isNotEmpty);
      expect(hasLoop.intersection(noEnding.keys.toSet()), isEmpty);
      expect(
        noEnding.values.every((why) => why.length > 40),
        isTrue,
        reason: 'an endless game must justify itself',
      );
    });

    test('every grid game is accounted for in the ledger', () {
      final ids = gridGames().map((g) => g.id).toSet();
      final unaccounted = ids
          .difference(hasLoop)
          .difference(noEnding.keys.toSet());
      expect(
        unaccounted,
        isEmpty,
        reason:
            'A new grid game must declare whether it can be finished — add '
            'it to hasLoop, or to noEnding with a reason: '
            "${unaccounted.join(', ')}",
      );
    });

    test('the clock games play themselves to an ending', () {
      // Only the ones whose ENDING is the clock. Simon has a clock too, but
      // it only plays the sequence back — Simon ends on wrong taps, and is
      // covered by its own test below. A puzzle needs the right moves, not
      // many moves: random tapping never solves Lights Out, which is a fact
      // about the test rather than about the game.
      const endsOnClockAlone = {'whack-a-mole', 'boggle'};
      for (final g in gridGames().where(
        (g) => endsOnClockAlone.contains(g.id),
      )) {
        var wire = GridBoard(
          cols: g.cols,
          rows: g.rows,
          cells: g.deal(bank()),
        ).toWire();
        var reachedEnd = false;
        for (var step = 0; step < 500; step++) {
          wire = g.reduce(wire, GameIntent.tick, const {});
          if (g.decode(wire).done) {
            reachedEnd = true;
            break;
          }
        }
        expect(reachedEnd, isTrue, reason: '${g.id} never runs out of clock');
        expect(
          g.decode(wire).outcome,
          isNotNull,
          reason: '${g.id} ends without saying anything',
        );
      }
    });

    test('every game deals a board with something on it', () {
      for (final g in gridGames()) {
        expect(
          g.deal(bank()),
          isNotEmpty,
          reason: '${g.id} deals an empty board — nothing to play',
        );
      }
    });

    test('no game throws on the content it is actually given', () {
      // Hangman read `payload['text']` off a CHARADES item, whose payload is
      // `{word, category}` — a null-check crash every time it opened, because
      // the bank always has charades. Fact or Fib did the same with `note`,
      // which the authoring form makes optional. A game that throws while
      // dealing is the most literal form of unplayable there is.
      for (final g in gridGames()) {
        expect(
          () => g.deal(bank()),
          returnsNormally,
          reason: '${g.id} throws while dealing',
        );
      }
    });

    test('no game throws on MINIMAL staff-authored content', () {
      // Every optional field left out, which is what a teacher who typed the
      // one required box actually produces.
      final minimal = LocalContentBank.seededWith([
        for (final entry in const {
          ContentKind.thisOrThat: {'a': 'x', 'b': 'y'},
          ContentKind.category: {'label': 'x'},
          ContentKind.line: {'text': 'x'},
          ContentKind.asIf: {'text': 'x'},
          ContentKind.riddle: {'prompt': 'x', 'answer': 'y'},
          ContentKind.factOrFib: {'statement': 'x', 'isTrue': true},
          ContentKind.storyStarter: {'text': 'x'},
          ContentKind.storyTwist: {'text': 'x'},
          ContentKind.rhymeWord: {'word': 'x'},
          ContentKind.charades: {'word': 'x', 'category': 'y'},
          ContentKind.question: {'text': 'x'},
          ContentKind.quote: {'text': 'x'},
          ContentKind.writePrompt: {'text': 'x'},
        }.entries)
          ContentItem(
            kind: entry.key,
            fingerprint: 'min-${entry.key}',
            payload: entry.value,
          ),
        for (var i = 0; i < 40; i++)
          ContentItem(
            kind: ContentKind.picture,
            fingerprint: 'pic$i',
            payload: {'image': 'assets/decks/pic$i.png', 'label': 'Card $i'},
          ),
      ]);
      for (final g in gridGames()) {
        expect(
          () => g.deal(minimal),
          returnsNormally,
          reason: '${g.id} throws on a minimally-authored bank',
        );
      }
    });

    test('each finished board is RECOGNISED as finished', () {
      // Hand-built terminal boards, one per game whose ending is a board
      // shape rather than a sequence of moves. This is what proves the
      // ending exists without having to play the puzzle correctly.
      GridBoard boardOf(GridGame g, List<BoardCell> cells) =>
          GridBoard(cols: g.cols, rows: g.rows, cells: cells);

      const lights = LightsOutGame();
      expect(
        lights.outcomeFor(
          boardOf(lights, [
            for (var i = 0; i < lights.cols * lights.rows; i++)
              const BoardCell(),
          ]),
        ),
        isNotNull,
        reason: 'every light off is the win',
      );

      const bingo = BingoGame();
      expect(
        bingo.outcomeFor(
          boardOf(bingo, [
            for (var i = 0; i < bingo.cols * bingo.rows; i++)
              const BoardCell(face: '★', state: CellState.done),
          ]),
        ),
        isNotNull,
        reason: 'a full card certainly contains a line',
      );

      const battleship = BattleshipGame();
      expect(
        battleship.outcomeFor(
          // Dealt by the game, then every square shot — a board of blank
          // cells has no ships on it to sink.
          boardOf(battleship, [
            for (final c in battleship.deal(bank()))
              c.copyWith(state: CellState.shown),
          ]),
        ),
        isNotNull,
        reason: 'every square shot means every ship hit',
      );

      const scavenger = ScavengerBingoGame();
      expect(
        scavenger.outcomeFor(
          boardOf(scavenger, [
            for (var i = 0; i < scavenger.cols * scavenger.rows; i++)
              const BoardCell(tint: CellTint.right),
          ]),
        ),
        isNotNull,
        reason: 'everything on the list found',
      );

      const guessWho = GuessWhoGame();
      final faces = [
        for (var i = 0; i < guessWho.cols * guessWho.rows; i++)
          BoardCell(
            face: 'f$i',
            state: i == 0 ? CellState.shown : CellState.done,
          ),
      ];
      expect(
        guessWho.outcomeFor(boardOf(guessWho, faces)),
        isNotNull,
        reason: 'one face left standing',
      );
    });
  });

  group('a board keeps its secrets', () {
    // The renderer draws a cell's FACE whenever there is one, whatever the
    // cell's state — "hidden" hides nothing by itself. A game that stores an
    // answer in a face MUST override `present`, or it puts the answer on the
    // screen. Battleship did not: all five ships were visible from the first
    // frame, and because a cell with a face never shows its label, the A1–E5
    // coordinates the game is played by never rendered either.
    test('battleship shows coordinates, not ships, before a shot', () {
      const g = BattleshipGame();
      final b = GridBoard(cols: g.cols, rows: g.rows, cells: g.deal(bank()));
      final shape = g.asShape(b)!;
      expect(
        shape.cells.every((c) => c.face == null),
        isTrue,
        reason: 'an unfired square must not show what is under it',
      );
      expect(
        shape.cells.every((c) => (c.label ?? '').isNotEmpty),
        isTrue,
        reason: 'it shows the coordinate the room calls out',
      );
    });

    test('battleship reveals a square once it is fired on', () {
      const g = BattleshipGame();
      var wire = g.initialState(bank());
      wire = g.reduce(wire, GameIntent.pick, const {'cell': 0});
      final shape = g.asShape(g.decode(wire))!;
      expect(shape.cells.first.face, isNotNull, reason: 'now you know');
    });

    test('guess who is thinking of somebody', () {
      // It held no secret: the room eliminated faces with nothing to converge
      // on, so the last face standing meant nothing and could be neither
      // right nor wrong.
      const g = GuessWhoGame();
      final b = g.decode(g.initialState(bank()));
      final secret = GuessWhoGame.secretOf(b);
      expect(secret, inInclusiveRange(0, g.cols * g.rows - 1));
      // And it never reaches the screen.
      final shape = g.asShape(b)!;
      expect(shape.note, isNot(contains('$secret')));
    });

    test('guess who says whether the room found the right face', () {
      const g = GuessWhoGame();
      final start = g.decode(g.initialState(bank()));
      final secret = GuessWhoGame.secretOf(start);
      // Knock out everyone but the secret.
      final right = start.copyWith(
        cells: [
          for (var i = 0; i < start.cells.length; i++)
            if (i == secret)
              start.cells[i]
            else
              start.cells[i].copyWith(state: CellState.done),
        ],
      );
      expect(g.outcomeFor(right), 'That is who!');

      // Knock out everyone but somebody else.
      final other = secret == 0 ? 1 : 0;
      final wrong = start.copyWith(
        cells: [
          for (var i = 0; i < start.cells.length; i++)
            if (i == other)
              start.cells[i]
            else
              start.cells[i].copyWith(state: CellState.done),
        ],
      );
      expect(g.outcomeFor(wrong), isNot('That is who!'));
      expect(g.outcomeFor(wrong), isNotNull);
    });

    test('bingo calls a square, by name', () {
      // Without a caller the card just sat there: nothing said what to mark,
      // so tapping any four in a row "won".
      const g = BingoGame();
      final b = g.decode(g.initialState(bank()));
      expect(BingoGame.calledOf(b), inInclusiveRange(0, b.cells.length - 1));
      expect(BingoGame.callOf(b), isNotNull, reason: 'and it says which');
      expect(g.asShape(b)!.title, BingoGame.callOf(b));
      // The name is storage — the picture is what the room sees.
      expect(g.asShape(b)!.cells.every((c) => c.face != null), isTrue);
    });

    test('marking the called square draws the next call', () {
      const g = BingoGame();
      var wire = g.initialState(bank());
      final first = BingoGame.calledOf(g.decode(wire));
      wire = g.reduce(wire, GameIntent.pick, {'cell': first});
      final after = g.decode(wire);
      expect(after.cells[first].state, CellState.done);
      expect(BingoGame.calledOf(after), isNot(first), reason: 'a new call');
    });

    test('marking an uncalled square does not change the call', () {
      const g = BingoGame();
      final wire = g.initialState(bank());
      final called = BingoGame.calledOf(g.decode(wire));
      final other = called == 0 ? 1 : 0;
      final after = g.decode(g.reduce(wire, GameIntent.pick, {'cell': other}));
      expect(
        BingoGame.calledOf(after),
        called,
        reason: 'pointing at the wrong picture costs nothing',
      );
    });

    test('word search shows the words it hid', () {
      const g = WordSearchGame();
      final b = GridBoard(cols: g.cols, rows: g.rows, cells: g.deal(bank()));
      final title = g.asShape(b)!.title ?? '';
      // Without the list the room was asked to find words it was never told,
      // which is not a hard game but an impossible one.
      expect(title, isNotEmpty);
      expect(title.split(RegExp(r'\s+')).length, greaterThanOrEqualTo(3));
    });
  });

  group('a room can take turns', () {
    // The point the whole deck was missing. Connect Four works because it
    // says whose go it is: the room splits into teams, argues, and one pair
    // of hands enters what they decided. A board with no sides is something
    // people look at.
    test('a two-sided game says whose turn it is, under the board', () {
      for (final g in gridGames().where((g) => g.alternates)) {
        final b = GridBoard(cols: g.cols, rows: g.rows, cells: g.deal(bank()));
        final note = g.asShape(b)!.note;
        expect(
          note,
          isNotNull,
          reason: '${g.id} alternates but never says whose go it is',
        );
      }
    });

    test('a typed answer hands over too', () {
      // The reducer used to flip the turn only on a TAP, so a typing game
      // could declare sides and then never change hands.
      const g = WordleGame();
      var wire = g.initialState(bank());
      final before = g.decode(wire).turn;
      wire = g.reduce(wire, GameIntent.capture, const {'text': 'CRANE'});
      expect(g.decode(wire).turn, isNot(before));
    });

    test('the turn actually changes hands on a move', () {
      for (final g in gridGames().where((g) => g.alternates)) {
        var wire = g.initialState(bank());
        final before = g.decode(wire).turn;
        // Find a MOVE the rule accepts — a tap, or a typed answer for the
        // games played by typing (their onPick is deliberately null).
        for (var i = 0; i < g.cols * g.rows; i++) {
          final next = g.reduce(wire, GameIntent.pick, {'cell': i});
          if (next != wire) {
            wire = next;
            break;
          }
        }
        if (g.decode(wire).turn == before && g.entryHint != null) {
          wire = g.reduce(wire, GameIntent.capture, {
            'text': 'CRANE'.substring(0, g.entryLength ?? 5),
          });
        }
        expect(
          g.decode(wire).turn,
          isNot(before),
          reason: '${g.id} never hands over',
        );
      }
    });

    test('snakes and ladders is a race, not a walk', () {
      // One token made it a solitaire walk to square 36 with no decision in
      // it and nobody to beat.
      const g = SnakesLaddersGame();
      var wire = g.initialState(bank());
      expect(SnakesLaddersGame.positionsOf(g.decode(wire)), [0, 0]);

      // One roll moves exactly ONE team.
      wire = g.reduce(wire, GameIntent.pick, const {'cell': 0});
      final after = SnakesLaddersGame.positionsOf(g.decode(wire));
      expect(after.where((p) => p > 0).length, 1, reason: 'one side moved');

      // Play it out; somebody gets home and is named.
      for (var i = 0; i < 400 && !g.decode(wire).done; i++) {
        wire = g.reduce(wire, GameIntent.pick, const {'cell': 0});
      }
      final end = g.decode(wire);
      expect(end.done, isTrue, reason: 'a race ends');
      expect(end.outcome, contains('home'));
    });

    test('a wrong answer costs the turn; a right one does not', () {
      // The rule the user asked for, and the reason conferring before you
      // answer is worth anything.
      const g = ScattergoriesGame();
      var wire = g.initialState(bank());
      final letter = ScattergoriesGame.letterOf(g.decode(wire));
      final before = g.decode(wire).turn;

      // Right: starts with the letter, board stays with the same team.
      wire = g.reduce(wire, GameIntent.capture, {'text': '${letter}pple'});
      expect(g.decode(wire).turn, before, reason: 'a good answer keeps it');
      expect(g.scoreOf(g.decode(wire), before), 1);

      // Wrong: does not start with the letter, board passes over.
      final wrongLetter = letter.toUpperCase() == 'Z' ? 'A' : 'Z';
      wire = g.reduce(wire, GameIntent.capture, {'text': '${wrongLetter}ebra'});
      expect(
        g.decode(wire).turn,
        isNot(before),
        reason: 'a wrong one costs it',
      );
    });

    test('closing a box means you go again', () {
      // The rule Dots & Boxes turns on. It was "implemented" by a helper that
      // returned the cells unchanged — an identity function with a comment
      // claiming it handed the turn back.
      //
      // Built deterministically: draw three edges of one box, then the
      // fourth. A loop that hopes to stumble on a closure can pass without
      // ever testing the rule.
      const g = DotsBoxesGame();
      const side = 7; // the board is side x side; box (1,1) sits at 1*7+1
      const box = 1 * side + 1;
      final edges = [
        (1 - 1) * side + 1,
        (1 + 1) * side + 1,
        1 * side + 0,
        1 * side + 2,
      ];
      var wire = g.initialState(bank());
      // Three edges: each hands over, so the turn alternates as normal.
      for (final e in edges.take(3)) {
        final next = g.reduce(wire, GameIntent.pick, {'cell': e});
        expect(next, isNot(wire), reason: 'edge $e must be playable');
        wire = next;
      }
      final before = g.decode(wire);
      expect(before.cells[box].face, isNull, reason: 'box still open');

      wire = g.reduce(wire, GameIntent.pick, {'cell': edges.last});
      final after = g.decode(wire);
      expect(after.cells[box].face, isNotNull, reason: 'the box closed');
      expect(
        after.turn,
        before.turn,
        reason: 'closing a box keeps the board — that is the whole game',
      );
    });

    test('battleship keeps score per side and names a winner', () {
      const g = BattleshipGame();
      var wire = g.initialState(bank());
      // Shoot every square; the two sides alternate as they go.
      for (var i = 0; i < g.cols * g.rows; i++) {
        wire = g.reduce(wire, GameIntent.pick, {'cell': i});
      }
      final b = g.decode(wire);
      expect(b.done, isTrue);
      expect(
        g.scoreOf(b, 0) + g.scoreOf(b, 1),
        5,
        reason: 'every hit belongs to somebody',
      );
      expect(b.outcome, isNotNull);
    });
  });

  group('whack-a-mole is a game, not a screen', () {
    const game = WhackAMoleGame();

    Map<String, dynamic> fresh() => game.initialState(bank());

    test('the mole moves on its OWN clock, with no tap at all', () {
      final start = game.decode(fresh());
      final startAt = start.cells.indexWhere((c) => c.face == '🐹');
      expect(startAt, isNot(-1), reason: 'a mole is dealt');

      final after = game.decode(
        game.reduce(start.toWire(), GameIntent.tick, const {}),
      );
      final afterAt = after.cells.indexWhere((c) => c.face == '🐹');
      expect(afterAt, isNot(startAt), reason: 'it moved without being hit');
    });

    test('a tick nobody caught is a miss, and misses end the round', () {
      var wire = fresh();
      for (var i = 0; i < 3; i++) {
        wire = game.reduce(wire, GameIntent.tick, const {});
      }
      final b = game.decode(wire);
      expect(b.score('miss'), 3);
      expect(b.done, isTrue, reason: 'three misses ends it');
      expect(b.outcome, isNotNull, reason: 'and it says so');
    });

    test('hitting the mole scores, and does not cost a life', () {
      final start = game.decode(fresh());
      final at = start.cells.indexWhere((c) => c.face == '🐹');
      final after = game.decode(
        game.reduce(start.toWire(), GameIntent.pick, {'cell': at}),
      );
      expect(after.score('hit'), 1);
      expect(after.score('miss'), 0);
      expect(after.done, isFalse);
    });

    test('tapping an empty square costs nothing', () {
      final start = game.decode(fresh());
      final at = start.cells.indexWhere((c) => c.face == '🐹');
      final empty = (at + 1) % start.cells.length;
      final after = game.reduce(start.toWire(), GameIntent.pick, {
        'cell': empty,
      });
      expect(after, start.toWire(), reason: 'the board is untouched');
    });

    test('a finished round takes no more taps', () {
      var wire = fresh();
      for (var i = 0; i < 3; i++) {
        wire = game.reduce(wire, GameIntent.tick, const {});
      }
      final ended = game.decode(wire);
      final at = ended.cells.indexWhere((c) => c.face == '🐹');
      final after = game.reduce(wire, GameIntent.pick, {'cell': at});
      expect(after, wire, reason: 'the board is frozen once the round is over');
    });

    test('reset deals a live board again', () {
      var wire = fresh();
      for (var i = 0; i < 3; i++) {
        wire = game.reduce(wire, GameIntent.tick, const {});
      }
      expect(game.decode(wire).done, isTrue);
      final again = game.decode(game.reduce(wire, GameIntent.reset, const {}));
      expect(again.done, isFalse);
      expect(again.score('miss'), 0);
      expect(again.score('hit'), 0);
    });

    test('the closing line becomes the stage title', () {
      var wire = fresh();
      for (var i = 0; i < 3; i++) {
        wire = game.reduce(wire, GameIntent.tick, const {});
      }
      final shape = game.asShape(game.decode(wire));
      expect(shape!.title, game.decode(wire).outcome);
    });
  });

  group('simon shows the pattern before asking for it', () {
    const game = SimonGame();

    GridBoard play(Map<String, dynamic> w) => game.decode(w);

    test('the board is talking on deal, so taps are ignored', () {
      final b = play(game.initialState(bank()));
      expect(SimonGame.showingOf(b), isTrue);
      final after = game.reduce(b.toWire(), GameIntent.pick, {'cell': 0});
      expect(
        after,
        b.toWire(),
        reason: 'a tap while it plays back does nothing',
      );
    });

    test('it lights each pad of the pattern, then falls silent', () {
      var wire = game.initialState(bank());
      final lit = <int>[];
      for (var i = 0; i < 6; i++) {
        wire = game.reduce(wire, GameIntent.tick, const {});
        final b = play(wire);
        final at = b.cells.indexWhere((c) => c.tint == CellTint.live);
        if (at >= 0) lit.add(at);
        if (!SimonGame.showingOf(b)) break;
      }
      expect(lit, isNotEmpty, reason: 'the room is shown something');
      expect(SimonGame.showingOf(play(wire)), isFalse, reason: 'then its turn');
    });

    test('three wrong taps end the round and report the best run', () {
      var wire = game.initialState(bank());
      for (var round = 0; round < 3; round++) {
        // Let it finish talking.
        for (var i = 0; i < 8 && SimonGame.showingOf(play(wire)); i++) {
          wire = game.reduce(wire, GameIntent.tick, const {});
        }
        final b = play(wire);
        if (b.done) break;
        final right = SimonGame.patternOf(b).first;
        wire = game.reduce(wire, GameIntent.pick, {'cell': (right + 1) % 4});
      }
      final b = play(wire);
      expect(b.score('wrong'), 3);
      expect(b.done, isTrue);
      expect(b.outcome, isNotNull);
    });
  });

  group('what a round leaves behind', () {
    // `GameDefinition.capture` was declared for this and is DEAD — never
    // overridden, and read by nothing, so overriding it would have done
    // nothing. `keepsake` replaces it, and the important half of the design is
    // that it is null for MOST games: a class memory full of "Team 1 wins,
    // 3–2" buries the few things actually worth keeping.
    test('almost every game keeps nothing, on purpose', () {
      final keepers = <String>[];
      for (final g in gridGames()) {
        final b = GridBoard(cols: g.cols, rows: g.rows, cells: g.deal(bank()));
        if (g.keepsake(b) != null) keepers.add(g.id);
      }
      expect(
        keepers.length,
        lessThan(4),
        reason: 'a keeper on every game is noise, not memory: $keepers',
      );
    });

    test('scattergories keeps the words the room actually produced', () {
      const g = ScattergoriesGame();
      final start = g.decode(g.initialState(bank()));
      // Nothing answered yet — nothing to keep.
      expect(g.keepsake(start), isNull);

      final letter = ScattergoriesGame.letterOf(start);
      var wire = start.toWire();
      for (final w in ['pple', 'nt', 'rm']) {
        wire = g.reduce(wire, GameIntent.capture, {'text': '$letter$w'});
      }
      final kept = g.keepsake(g.decode(wire));
      expect(kept, isNotNull);
      expect(kept, contains(letter));
      expect(
        kept,
        contains('·'),
        reason: 'it keeps the answers, not just that the round happened',
      );
    });
  });

  group('the tally survives the wire', () {
    test('counters round-trip so a cast screen sees the same score', () {
      const game = WhackAMoleGame();
      var wire = game.initialState(bank());
      wire = game.reduce(wire, GameIntent.tick, const {});
      final decoded = GridBoard.fromWire(
        Map<String, dynamic>.from(game.decode(wire).toWire()),
      );
      expect(decoded.score('miss'), 1);
    });
  });
}
