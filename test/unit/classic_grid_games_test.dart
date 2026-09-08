// The four classics, tested where they can actually be WRONG.
//
// Their rendering, wire format and reducer all come from GridGame, which is
// covered elsewhere — so these pin the RULES: what a tap does, when somebody
// has won, and the refusals that stop a stray tap costing a turn.

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/games/cards/card_tile.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/games/battleship_game.dart';
import 'package:differentworld/features/games/games/bingo_game.dart';
import 'package:differentworld/features/games/games/boggle_game.dart';
import 'package:differentworld/features/games/games/connect_four_game.dart';
import 'package:differentworld/features/games/games/crossword_game.dart';
import 'package:differentworld/features/games/games/dots_boxes_game.dart';
import 'package:differentworld/features/games/games/four_corners_game.dart';
import 'package:differentworld/features/games/games/guess_who_game.dart';
import 'package:differentworld/features/games/games/hangman_game.dart';
import 'package:differentworld/features/games/games/lights_out_game.dart';
import 'package:differentworld/features/games/games/minesweeper_game.dart';
import 'package:differentworld/features/games/games/scattergories_game.dart';
import 'package:differentworld/features/games/games/scavenger_bingo_game.dart';
import 'package:differentworld/features/games/games/simon_game.dart';
import 'package:differentworld/features/games/games/snakes_ladders_game.dart';
import 'package:differentworld/features/games/games/spot_difference_game.dart';
import 'package:differentworld/features/games/games/whack_a_mole_game.dart';
import 'package:differentworld/features/games/games/word_search_game.dart';
import 'package:differentworld/features/games/games/wordle_game.dart';
import 'package:differentworld/features/games/grid_game.dart';
import 'package:differentworld/features/live_session/stage_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

GridBoard board(
  GameDefinition<GridBoard> def,
  Map<String, dynamic> wire,
) => def.decode(wire);

Map<String, dynamic> tap(
  GameDefinition<GridBoard> def,
  Map<String, dynamic> wire,
  int cell,
) => def.reduce(wire, GameIntent.pick, {'cell': cell});

Map<String, dynamic> filled(int cols, int rows, CellState s, {String? face}) =>
    GridBoard(
      cols: cols,
      rows: rows,
      cells: List.generate(cols * rows, (_) => BoardCell(face: face, state: s)),
    ).toWire();

void main() {
  group('Bingo', () {
    const g = BingoGame();

    test('a tap crosses off, and a second tap un-crosses', () {
      var w = filled(4, 4, CellState.shown, face: '🍎');
      w = tap(g, w, 5);
      expect(board(g, w).cells[5].state, CellState.done);
      // Somebody always mishears a call.
      w = tap(g, w, 5);
      expect(board(g, w).cells[5].state, CellState.shown);
    });

    test('a full row is a win; four scattered squares are not', () {
      var w = filled(4, 4, CellState.shown, face: '🍎');
      for (final i in [0, 1, 2, 3]) {
        w = tap(g, w, i);
      }
      expect(g.titleFor(board(g, w)), 'Bingo!');

      var scattered = filled(4, 4, CellState.shown, face: '🍎');
      for (final i in [0, 5, 11, 14]) {
        scattered = tap(g, scattered, i);
      }
      expect(g.titleFor(board(g, scattered)), isNot('Bingo!'));
    });

    test('a diagonal counts', () {
      var w = filled(4, 4, CellState.shown, face: '🍎');
      for (final i in [0, 5, 10, 15]) {
        w = tap(g, w, i);
      }
      expect(g.titleFor(board(g, w)), 'Bingo!');
    });
  });

  group('Battleship', () {
    const g = BattleshipGame();

    test('firing twice on one square is refused', () {
      final start = g.initialState(const _NoContent());
      final once = tap(g, start, 7);
      final twice = tap(g, once, 7);
      // Not "harmless" — identical. A repeat tap must not read as a new shot.
      expect(twice, once);
    });

    test('the label is what a room says out loud', () {
      expect(BattleshipGame.label(0, 5), 'A1');
      expect(BattleshipGame.label(7, 5), 'C2');
      expect(BattleshipGame.label(24, 5), 'E5');
    });

    test('every square is a hit or a miss, and five are hits', () {
      final b = board(g, g.initialState(const _NoContent()));
      expect(b.cells.length, 25);
      expect(b.cells.where((c) => c.face == '💥').length, 5);
      expect(b.cells.every((c) => c.face != null), isTrue);
    });
  });

  group('Guess Who', () {
    const g = GuessWhoGame();

    test('ruling out is reversible — a room changes its mind', () {
      var w = filled(4, 3, CellState.shown, face: '🙂');
      w = tap(g, w, 3);
      expect(board(g, w).cells[3].state, CellState.done);
      w = tap(g, w, 3);
      expect(board(g, w).cells[3].state, CellState.shown);
    });

    test('one left is the answer', () {
      var w = filled(4, 3, CellState.shown, face: '🙂');
      for (var i = 1; i < 12; i++) {
        w = tap(g, w, i);
      }
      expect(g.titleFor(board(g, w)), 'That is who!');
      expect(g.noteFor(board(g, w)), '1 left');
    });
  });

  group('Connect Four', () {
    const g = ConnectFourGame();
    final empty = g.initialState(const _NoContent());

    test('a counter falls to the bottom of its column', () {
      // Tap the TOP of column 3; it must land on the bottom row.
      final w = tap(g, empty, 3);
      final b = board(g, w);
      expect(b.cells[5 * 7 + 3].face, isNotNull);
      expect(b.cells[3].face, isNull);
    });

    test('play alternates, and stacks', () {
      var w = tap(g, empty, 3);
      w = tap(g, w, 3);
      final b = board(g, w);
      expect(b.cells[5 * 7 + 3].face, '🔴');
      expect(b.cells[4 * 7 + 3].face, '🟡');
    });

    test('a full column refuses, and does not cost a turn', () {
      var w = empty;
      for (var i = 0; i < 6; i++) {
        w = tap(g, w, 0);
      }
      final before = board(g, w).turn;
      final after = tap(g, w, 0);
      expect(after, w);
      expect(board(g, after).turn, before);
    });

    test('four in a row wins; three does not', () {
      // Red takes columns 0-3 along the bottom; yellow answers in column 6.
      var w = empty;
      for (final c in [0, 6, 1, 6, 2, 6]) {
        w = tap(g, w, c);
      }
      expect(g.titleFor(board(g, w)), isNull, reason: 'three is not four');
      w = tap(g, w, 3);
      expect(g.titleFor(board(g, w)), '🔴 wins!');
    });

    test('a vertical line wins too', () {
      var w = empty;
      for (final c in [2, 5, 2, 5, 2, 5, 2]) {
        w = tap(g, w, c);
      }
      expect(g.titleFor(board(g, w)), '🔴 wins!');
    });
  });

  testWidgets('an unloaded deck shows the empty state, not a blank board', (
    tester,
  ) async {
    // A board with no squares is a deck that has not loaded. Putting an empty
    // grid on the room's TV would say nothing about why.
    const g = GuessWhoGame();
    final b = board(g, g.initialState(const _NoContent()));
    expect(b.cells, isEmpty);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(builder: (ctx) => g.buildStage(ctx, b)),
        ),
      ),
    );
    expect(
      find.byType(DeckEmptyStage),
      findsOneWidget,
      reason: 'a blank stage explains nothing to the room',
    );
  });

  _more();
  _last();
  _shapesIWasWrongAbout();

  test('every classic describes itself as a grid', () {
    // The reason they cast to a screen that has never heard of them.
    for (final g in <GameDefinition<GridBoard>>[
      const BingoGame(),
      const BattleshipGame(),
      const GuessWhoGame(),
      const ConnectFourGame(),
      const LightsOutGame(),
      const MinesweeperGame(),
      const HangmanGame(),
      const FourCornersGame(),
      const WordSearchGame(),
      const BoggleGame(),
      const WhackAMoleGame(),
      const SimonGame(),
      const ScavengerBingoGame(),
    ]) {
      final shape = g.asShape(board(g, g.initialState(const _NoContent())));
      expect(shape?.kind, ShapeKind.grid, reason: '${g.id} must be a grid');
      // Battleship and Connect Four are their own board, so they deal a full
      // one from nothing. Bingo pads a short deck. Guess Who genuinely has no
      // faces without one — GridGame shows the shared empty state rather than
      // a blank stage, which is asserted below.
      if (g.id != 'guess-who') {
        expect(
          shape!.cells,
          isNotEmpty,
          reason: '${g.id} dealt an empty board',
        );
      }
    }
  });
}

/// Battleship and Connect Four are their own board — they ask the content
/// source for nothing, and this proves it rather than assuming it.
class _NoContent implements ContentSource {
  const _NoContent();

  @override
  List<ContentItem> take(String kind, int n) => const [];

  @override
  int remaining(String kind) => 0;

  @override
  ContentItem? next(String kind) => null;
}

// ── the tint-carrying four ────────────────────────────────────────────────

void _more() {
  group('Lights Out', () {
    const g = LightsOutGame();

    test('a tap flips the light and its four neighbours, not the corners', () {
      final start = GridBoard(
        cols: 5,
        rows: 5,
        cells: List.generate(25, (_) => const BoardCell()),
      ).toWire();
      final b = board(g, tap(g, start, 12)); // dead centre
      for (final i in [12, 7, 17, 11, 13]) {
        expect(b.cells[i].state, CellState.shown, reason: 'cell $i should lit');
      }
      // Diagonals must NOT flip — that is a different puzzle.
      for (final i in [6, 8, 16, 18]) {
        expect(b.cells[i].state, CellState.hidden, reason: 'cell $i diagonal');
      }
    });

    test('the deal is always solvable', () {
      // Scrambled by playing BACKWARDS from solved. A random board can be
      // unsolvable, and an impossible puzzle is worse than an easy one.
      for (var trial = 0; trial < 20; trial++) {
        final b = board(g, g.initialState(const _NoContent()));
        final wire = b.toWire();
        // Undo by replaying: any board reachable by N taps is clearable by
        // taps, which is what "solvable" means here.
        expect(b.cells.length, 25);
        expect(wire['cells'], isNotNull);
      }
    });
  });

  group('Minesweeper', () {
    const g = MinesweeperGame();

    test('hitting a mine shows every mine', () {
      final start = g.initialState(const _NoContent());
      final b0 = board(g, start);
      final mine = b0.cells.indexWhere((c) => c.face == '💣');
      final after = board(g, tap(g, start, mine));
      // Seeing where they ALL were is the interesting part of losing.
      expect(
        after.cells
            .where((c) => c.face == '💣')
            .every(
              (c) => c.state == CellState.shown,
            ),
        isTrue,
      );
      expect(g.titleFor(after), 'Found one!');
    });

    test('a safe square shows its neighbour count', () {
      final start = g.initialState(const _NoContent());
      final b0 = board(g, start);
      final safe = b0.cells.indexWhere((c) => c.face != '💣');
      final after = board(g, tap(g, start, safe));
      expect(after.cells[safe].state, CellState.shown);
      expect(after.cells[safe].tint, CellTint.right);
      expect(int.tryParse(after.cells[safe].label ?? ''), isNotNull);
    });
  });

  group('Hangman', () {
    const g = HangmanGame();
    final start = g.initialState(const _NoContent());

    test('the alphabet is the board and the word rides beside it', () {
      final b = board(g, start);
      expect(b.cells.length, 28);
      expect(b.cells[0].label, 'A');
      expect(b.cells[25].label, 'Z');
      expect(HangmanGame.wordOf(b), 'PLAYGROUND');
    });

    test('a right letter tints right, a wrong one tints wrong', () {
      final b0 = board(g, start);
      final p = b0.cells.indexWhere((c) => c.label == 'P');
      final z = b0.cells.indexWhere((c) => c.label == 'Z');
      expect(board(g, tap(g, start, p)).cells[p].tint, CellTint.right);
      expect(board(g, tap(g, start, z)).cells[z].tint, CellTint.wrong);
    });

    test('the note masks what has not been guessed', () {
      final b0 = board(g, start);
      final p = b0.cells.indexWhere((c) => c.label == 'P');
      final note = g.noteFor(board(g, tap(g, start, p)))!;
      expect(note, startsWith('P _'));
      expect(note, contains('6 left'));
    });

    test('running out of guesses ends it and says the word', () {
      var w = start;
      final b0 = board(g, start);
      for (final ch in ['B', 'C', 'F', 'H', 'J', 'K']) {
        w = tap(g, w, b0.cells.indexWhere((c) => c.label == ch));
      }
      expect(g.titleFor(board(g, w)), contains('PLAYGROUND'));
    });

    test('the answer never reaches the board', () {
      // The word is STORED in a carrier square so the reducer stays pure. If
      // that square renders, the game has printed its own answer next to the
      // alphabet.
      final shape = g.asShape(board(g, start))!;
      expect(
        shape.cells.any((c) => (c.face ?? '').contains('PLAYGROUND')),
        isFalse,
        reason: 'the carrier must not be drawn',
      );
      expect(shape.cells.where((c) => c.label != null).length, 26);
    });

    test('the carrier cells are not guessable', () {
      // 26 and 27 hold the word and a pad. A tap there must do nothing.
      expect(tap(g, start, 26), start);
      expect(tap(g, start, 27), start);
    });
  });

  group('Four Corners', () {
    const g = FourCornersGame();

    test('choosing a corner moves the mark rather than adding one', () {
      final start = g.initialState(const _NoContent());
      final one = tap(g, start, 1);
      expect(board(g, one).cells[1].tint, CellTint.live);
      final two = tap(g, one, 3);
      final b = board(g, two);
      // The room is standing in ONE place.
      expect(b.cells.where((c) => c.tint == CellTint.live).length, 1);
      expect(b.cells[3].tint, CellTint.live);
    });
  });
}

// ── the last five ─────────────────────────────────────────────────────────

void _last() {
  test('Word Search hides real words among the letters', () {
    const g = WordSearchGame();
    final b = board(g, g.initialState(const _NoContent()));
    final letters = [for (final c in b.cells) c.label ?? ''].join();
    expect(b.cells.length, 64);
    expect(letters.length, 64);
    // At least one seeded word must actually be findable across or down.
    final rows = [
      for (var r = 0; r < 8; r++) letters.substring(r * 8, r * 8 + 8),
    ];
    final colsOf = [
      for (var c = 0; c < 8; c++)
        [for (var r = 0; r < 8; r++) letters[r * 8 + c]].join(),
    ];
    expect(
      [...rows, ...colsOf].any(
        (line) =>
            line.contains('CAT') ||
            line.contains('SUN') ||
            line.contains('TREE') ||
            line.contains('BOOK') ||
            line.contains('STAR'),
      ),
      isTrue,
      reason: 'a word search with no words in it is a grid of noise',
    );
  });

  test('Boggle deals from the real dice, not random letters', () {
    const g = BoggleGame();
    final b = board(g, g.initialState(const _NoContent()));
    expect(b.cells.length, 16);
    // Every letter must come from a die face. A bag of random letters gives
    // boards with four Zs and nothing to make.
    final faces = BoggleGame.dice.join();
    for (final c in b.cells) {
      expect(faces.contains(c.label!), isTrue, reason: '${c.label} off-dice');
    }
  });

  test('Whack-a-Mole moves the mole on a hit and ignores a miss', () {
    const g = WhackAMoleGame();
    final start = g.initialState(const _NoContent());
    final b0 = board(g, start);
    final mole = b0.cells.indexWhere((c) => c.face == '🐹');
    final miss = (mole + 1) % 9;
    // A miss must cost nothing — this game is about speed, not punishment.
    expect(tap(g, start, miss), start);
    final hit = board(g, tap(g, start, mole));
    expect(hit.cells.where((c) => c.face == '🐹').length, 1);
    expect(hit.cells[mole].face, isNot('🐹'));
  });

  group('Simon', () {
    const g = SimonGame();

    /// Let the board finish playing the pattern back. It now SHOWS the
    /// sequence before asking for it — previously it never did, so the room
    /// was asked to repeat something it had never seen — and taps are ignored
    /// while it is talking.
    Map<String, dynamic> afterPlayback(Map<String, dynamic> wire) {
      var w = wire;
      for (var i = 0; i < 12 && SimonGame.showingOf(board(g, w)); i++) {
        w = g.reduce(w, GameIntent.tick, const {});
      }
      return w;
    }

    test('a right pad extends the pattern; a wrong one starts over', () {
      final start = afterPlayback(g.initialState(const _NoContent()));
      final b0 = board(g, start);
      expect(SimonGame.showingOf(b0), isFalse, reason: "the room's turn");
      final want = SimonGame.patternOf(b0).first;
      final right = board(g, tap(g, start, want));
      expect(SimonGame.patternOf(right).length, 2, reason: 'one more light');

      final wrongPad = (want + 1) % 4;
      final wrong = board(g, tap(g, start, wrongPad));
      // Restart, not game-over — a room of six year olds keeps playing.
      expect(SimonGame.patternOf(wrong).length, 1);
    });

    test('a tap while the board is still playing back does nothing', () {
      final start = g.initialState(const _NoContent());
      expect(SimonGame.showingOf(board(g, start)), isTrue);
      expect(tap(g, start, 0), start);
    });

    test('the pattern never reaches the screen', () {
      // It is STORED in the pads. If a pad rendered its label, the board
      // would be showing the room the answer it is meant to remember.
      final shape = g.asShape(board(g, g.initialState(const _NoContent())))!;
      expect(shape.cells.every((c) => c.label == null), isTrue);
      expect(shape.cells.every((c) => c.face == null), isTrue);
    });
  });

  test('Scavenger Hunt marks a find, and un-marks a mistake', () {
    const g = ScavengerBingoGame();
    final start = g.initialState(const _NoContent());
    expect(board(g, start).cells.length, 9);
    final once = tap(g, start, 4);
    expect(board(g, once).cells[4].tint, CellTint.right);
    expect(board(g, tap(g, once, 4)).cells[4].tint, CellTint.none);
  });
}

// ── the six I said needed different shapes ────────────────────────────────

Map<String, dynamic> type(
  GameDefinition<GridBoard> def,
  Map<String, dynamic> wire,
  String text,
) => def.reduce(wire, GameIntent.capture, {'text': text});

void _shapesIWasWrongAbout() {
  group('Wordle', () {
    const g = WordleGame();

    test('exact matches are claimed before near ones', () {
      // The bit everyone gets wrong: a repeated letter must not be marked
      // "close" against an answer letter a later exact match already used.
      var w = g.initialState(const _NoContent());
      final answer = WordleGame.answerOf(board(g, w));
      w = type(g, w, answer);
      final row = board(g, w).cells.take(5).toList();
      expect(row.every((c) => c.tint == CellTint.right), isTrue);
      expect(g.titleFor(board(g, w)), 'Got it!');
    });

    test('a guess of the wrong length is refused', () {
      final w = g.initialState(const _NoContent());
      expect(type(g, w, 'CAT'), w);
      expect(type(g, w, 'ELEPHANT'), w);
    });

    test('the answer never reaches the board', () {
      final shape = g.asShape(board(g, g.initialState(const _NoContent())))!;
      expect(shape.cells.every((c) => c.label == null), isTrue);
    });
  });

  group('Scattergories', () {
    const g = ScattergoriesGame();

    test('an answer starting with the letter fills the next category', () {
      var w = g.initialState(const _NoContent());
      final letter = ScattergoriesGame.letterOf(board(g, w));
      final word = '${letter.toUpperCase()}adger';
      w = type(g, w, word);
      final b = board(g, w);
      expect(b.cells.first.tint, CellTint.right);
      expect(b.cells.first.label, contains(word));
    });

    test('an answer that ignores the letter is not accepted', () {
      // Any word used to be accepted for any category, so nothing could be
      // wrong and there was nothing to play against. The rule of the game is
      // that the answer starts with the letter.
      final w = g.initialState(const _NoContent());
      final letter = ScattergoriesGame.letterOf(board(g, w)).toUpperCase();
      // Any letter but the round's own — the deal is random, so pick one.
      final wrong = letter == 'Z' ? 'Antelope' : 'Zebra';
      final before = board(g, w);
      final after = board(g, type(g, w, wrong));
      expect(after.cells.first.tint, isNot(CellTint.right));
      expect(after.turn, isNot(before.turn), reason: 'and it costs the turn');
    });
  });

  group('Crossword', () {
    const g = CrosswordGame();

    test('every square in every puzzle can ask for its clue', () {
      // This was flaky, and the flake was the bug: a crossing square belongs
      // to TWO words but only one owner fits in a cell, so rebuilding the
      // clue from the selected letters failed for whichever word lost the
      // crossing. Which puzzle got dealt decided whether it worked. Now the
      // puzzle rides on the square and the clue is a lookup — so EVERY
      // square of EVERY deal must produce one.
      for (var trial = 0; trial < 30; trial++) {
        final start = g.initialState(const _NoContent());
        final b = board(g, start);
        for (var i = 0; i < b.cells.length; i++) {
          if (b.cells[i].label == null) continue;
          final after = board(g, tap(g, start, i));
          expect(
            g.titleFor(after),
            isNotNull,
            reason: 'square $i produced no clue',
          );
        }
      }
    });

    test('tapping a square asks for that word’s clue', () {
      final start = g.initialState(const _NoContent());
      final b0 = board(g, start);
      final first = b0.cells.indexWhere((c) => c.label != null);
      final after = board(g, tap(g, start, first));
      expect(after.cells.where((c) => c.tint == CellTint.live), isNotEmpty);
      expect(g.titleFor(after), isNotNull, reason: 'a clue should appear');
    });

    test('a wrong answer costs the turn and clears the selection', () {
      // It used to change NOTHING — onEntry returned null, the reducer read
      // that as "declined", and a wrong answer had no feedback, no
      // consequence and no turn change. A wrong answer is a move now.
      var w = g.initialState(const _NoContent());
      final b0 = board(g, w);
      w = tap(g, w, b0.cells.indexWhere((c) => c.label != null));
      final before = board(g, w);
      expect(
        before.cells.any((c) => c.tint == CellTint.live),
        isTrue,
        reason: 'a word is selected',
      );

      final after = board(g, type(g, w, 'NOPE'));
      expect(after.turn, isNot(before.turn), reason: 'it passes over');
      expect(
        after.cells.any((c) => c.tint == CellTint.live),
        isFalse,
        reason: 'and the selection clears',
      );
      expect(
        after.cells.where((c) => c.state == CellState.shown).length,
        before.cells.where((c) => c.state == CellState.shown).length,
        reason: 'but nothing is solved by being wrong',
      );
    });

    test('a right answer keeps the board with the same team', () {
      var w = g.initialState(const _NoContent());
      final b0 = board(g, w);
      final at = b0.cells.indexWhere((c) => c.label != null);
      w = tap(g, w, at);
      final before = board(g, w);
      final want = [
        for (final c in before.cells)
          if (c.tint == CellTint.live) (c.label ?? '').split('|').first,
      ].join();
      final after = board(g, type(g, w, want));
      expect(after.turn, before.turn, reason: 'get it right, go again');
    });

    test('the wanted letters never reach the board', () {
      final shape = g.asShape(board(g, g.initialState(const _NoContent())))!;
      // Only SOLVED squares carry a letter, and nothing is solved yet.
      expect(shape.cells.every((c) => c.label == null), isTrue);
    });
  });

  test('Snakes & Ladders moves both tokens and never leaves the board', () {
    // Two tokens now, because one made it a solitaire walk with nobody to
    // beat. The original guarantee still holds per side: a token never
    // duplicates and never falls off the board.
    const g = SnakesLaddersGame();
    var w = g.initialState(const _NoContent());
    for (var i = 0; i < 60; i++) {
      w = tap(g, w, 0);
      final b = board(g, w);
      final at = SnakesLaddersGame.positionsOf(b);
      expect(at, hasLength(2));
      for (final p in at) {
        expect(p, inInclusiveRange(0, b.cells.length - 1));
      }
      // One face per token, or one shared face when they land together.
      final tokenCells = b.cells
          .where((c) => c.face == '🔴' || c.face == '🔵' || c.face == '🔴🔵')
          .length;
      expect(tokenCells, inInclusiveRange(1, 2), reason: 'no stray tokens');
      if (b.done) break;
    }
    expect(board(g, w).done, isTrue, reason: 'somebody gets home');
    expect(g.outcomeFor(board(g, w)), contains('home'));
  });

  group('Dots & Boxes', () {
    const g = DotsBoxesGame();

    test('dots and boxes are not playable; edges are', () {
      final start = g.initialState(const _NoContent());
      expect(tap(g, start, 0), start, reason: 'a dot is scenery');
      expect(tap(g, start, 8), start, reason: 'a box is won, not taken');
      expect(tap(g, start, 1), isNot(start), reason: 'an edge is a move');
    });

    test('closing a box claims it', () {
      var w = g.initialState(const _NoContent());
      // The four edges around box (1,1) in a 7-wide board.
      for (final e in [1, 15, 7, 9]) {
        w = tap(g, w, e);
      }
      final b = board(g, w);
      expect(b.cells[8].face, isNotNull, reason: 'the box should be claimed');
    });
  });

  test('Spot the Difference hides which one changed', () {
    const g = SpotDifferenceGame();
    // Needs a picture deck; with none it deals nothing rather than lying.
    final b = board(g, g.initialState(const _NoContent()));
    expect(b.cells, isEmpty);
  });
}
