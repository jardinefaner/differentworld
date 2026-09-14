import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/facilitation/activity_run_scripts.dart';
import 'package:differentworld/features/facilitation/run_script_wire.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/games/bingo_game.dart';
import 'package:differentworld/features/games/games/charades_game.dart';
import 'package:differentworld/features/games/games/connect_four_game.dart';
import 'package:differentworld/features/games/games/lights_out_game.dart';
import 'package:flutter_test/flutter_test.dart';

/// The run-script exists so a SUBSTITUTE can start any activity by finding
/// Next. These pin the shape; the ledger at the bottom pins the honest count,
/// because "some games have instructions" is the state this is meant to leave
/// behind, not arrive at.
void main() {
  _wireTests();
  group('run-script', () {
    test('the three pilots answer what, how it ends, and who starts', () {
      final pilots = <GameDefinition<dynamic>>[
        const ConnectFourGame(),
        const BingoGame(),
        const CharadesGame(),
      ];
      for (final g in pilots) {
        final script = g.howToPlay;
        expect(script.length, greaterThanOrEqualTo(3), reason: g.id);
        expect(script.length, lessThanOrEqualTo(6), reason: '${g.id} too long');
        // The first beat names the game, so a child arriving late can orient
        // without asking the adult — who may not know either.
        expect(script.first.line.toLowerCase(), contains('playing'));
        for (final b in script) {
          expect(b.line.trim(), isNotEmpty);
          // Read across a room, not off a page.
          expect(b.line.length, lessThan(48), reason: '${g.id}: ${b.line}');
          expect(b.detail?.trim(), isNot(''));
        }
      }
    });

    test('a script never repeats a line', () {
      for (final g in liveGames.where((g) => g.howToPlay.isNotEmpty)) {
        final lines = g.howToPlay.map((b) => b.line).toList();
        expect(lines.toSet().length, lines.length, reason: g.id);
      }
    });

    test('EVERY game script stays readable across a room', () {
      // The pilots got this check when there were three of them; it has to
      // cover the whole set or the eleventh script is the unchecked one.
      for (final g in liveGames.where((g) => g.howToPlay.isNotEmpty)) {
        final script = g.howToPlay;
        expect(script.length, greaterThanOrEqualTo(3), reason: g.id);
        expect(script.length, lessThanOrEqualTo(6), reason: '${g.id} too long');
        for (final b in script) {
          expect(b.line.trim(), isNotEmpty, reason: g.id);
          expect(b.line.length, lessThan(48), reason: '${g.id}: ${b.line}');
          expect(b.detail?.trim(), isNot(''), reason: g.id);
        }
      }
    });

    test('every activity script answers what, and stays readable', () {
      for (final entry in activityRunScripts.entries) {
        final script = entry.value;
        expect(script.length, greaterThanOrEqualTo(3), reason: entry.key);
        expect(script.length, lessThanOrEqualTo(6), reason: entry.key);
        for (final b in script) {
          expect(b.line.trim(), isNotEmpty, reason: entry.key);
          expect(
            b.line.length,
            lessThan(48),
            reason: '${entry.key}: ${b.line}',
          );
          expect(b.detail?.trim(), isNot(''));
        }
        expect(
          script.map((b) => b.line).toSet().length,
          script.length,
          reason: '${entry.key} repeats a line',
        );
      }
    });

    test('the three a substitute has never done before are covered', () {
      // Not an arbitrary list. A sub has played Connect Four as a child; they
      // have never done any of these, so an empty script here is the activity
      // simply not happening.
      for (final route in const [
        '/activity/discussions',
        '/activity/roles',
        '/activity/pattern',
      ]) {
        expect(activityRunScripts[route], isNotNull, reason: route);
      }
    });

    test('two cockpit surfaces have NO script, on purpose', () {
      // The same shape as the grid-game ledger's `noEnding`: an exception with
      // a written reason, so nobody later "fixes" it.
      const noScript = {
        // Signals is an interruption — Eyes up, Freeze, Line up. A signal that
        // needs three taps of preamble is not a signal. The whole value is
        // that it lands the instant the adult reaches for it.
        'cues': 'it is an interruption, not an activity',
        // A countdown explains itself, and the adult reaching for it is
        // usually mid-transition with a room already moving.
        'timer': 'a clock needs no rules',
      };
      for (final entry in noScript.entries) {
        final g = liveGames.firstWhere((g) => g.id == entry.key);
        expect(g.howToPlay, isEmpty, reason: '${entry.key}: ${entry.value}');
      }
    });

    test('the ledger: how much of the deck a substitute could start', () {
      final withScript = liveGames.where((g) => g.howToPlay.isNotEmpty).length;
      // Deliberately an equality, not a floor. When the next batch lands this
      // test FAILS and the number gets updated — which is the point. A ">= 3"
      // would sit green forever while 38 games stayed unrunnable, and the
      // whole reason this feature exists is that nobody could see that gap.
      expect(
        withScript,
        13,
        reason:
            'Update this count as run-scripts land. $withScript of '
            '${liveGames.length} games can be started by someone who does '
            'not know the rules.',
      );
      // The activity half of the same ledger, and the same equality for the
      // same reason: a floor would sit green while the rest stayed unrunnable.
      expect(
        activityRunScripts.length,
        3,
        reason:
            '${activityRunScripts.length} of 11 non-game activities have a '
            'run-script.',
      );
    });
  });
}

/// The cursor in the WIRE — the half that makes a script reach the room
/// rather than only the phone holding it.
void _wireTests() {
  group('run-script wire', () {
    const g = ConnectFourGame();

    Map<String, dynamic> seeded() =>
        RunScriptWire.seed(g, g.initialState(LocalContentBank.seeded()));

    test('a scripted game opens on its first beat', () {
      expect(RunScriptWire.indexOf(seeded()), 0);
    });

    test('a game with no script is never seeded', () {
      const plain = LightsOutGame();
      final wire = RunScriptWire.seed(
        plain,
        plain.initialState(LocalContentBank.seeded()),
      );
      expect(RunScriptWire.indexOf(wire), isNull);
      expect(wire.containsKey(RunScriptWire.key), isFalse);
    });

    test('next walks the beats, then hands the board over', () {
      var wire = seeded();
      for (var i = 1; i < g.howToPlay.length; i++) {
        wire = RunScriptWire.reduce(g, wire, GameIntent.next, const {});
        expect(RunScriptWire.indexOf(wire), i);
      }
      wire = RunScriptWire.reduce(g, wire, GameIntent.next, const {});
      // Absent, not -1: the board owns the screen from here.
      expect(RunScriptWire.indexOf(wire), isNull);
      expect(wire.containsKey(RunScriptWire.key), isFalse);
    });

    test('back steps, and stops at the first beat', () {
      var wire = RunScriptWire.reduce(g, seeded(), GameIntent.next, const {});
      expect(RunScriptWire.indexOf(wire), 1);
      wire = RunScriptWire.reduce(g, wire, GameIntent.back, const {});
      expect(RunScriptWire.indexOf(wire), 0);
      wire = RunScriptWire.reduce(g, wire, GameIntent.back, const {});
      expect(RunScriptWire.indexOf(wire), 0, reason: 'no beat -1');
    });

    test('the board cannot start behind the instructions', () {
      // The defect this guards: a stray tap during the rules quietly playing a
      // move, which the adult reading the beats aloud would never see.
      final wire = seeded();
      final after = RunScriptWire.reduce(g, wire, GameIntent.pick, {'cell': 0});
      expect(after, wire, reason: 'pick is swallowed while briefing');
      expect(RunScriptWire.indexOf(after), 0, reason: 'still on beat one');
    });

    test('play again re-briefs — a second round has new children in it', () {
      var wire = seeded();
      for (var i = 0; i < g.howToPlay.length; i++) {
        wire = RunScriptWire.reduce(g, wire, GameIntent.next, const {});
      }
      expect(RunScriptWire.indexOf(wire), isNull);
      wire = RunScriptWire.reduce(g, wire, GameIntent.reset, const {});
      expect(RunScriptWire.indexOf(wire), 0);
    });
  });
}
