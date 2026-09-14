import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/facilitation/activity_run_scripts.dart';
import 'package:differentworld/features/facilitation/run_script_wire.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/games/bingo_game.dart';
import 'package:differentworld/features/games/games/charades_game.dart';
import 'package:differentworld/features/games/games/connect_four_game.dart';
import 'package:differentworld/features/games/games/lights_out_game.dart';
import 'package:differentworld/features/games/games/timer_game.dart';
import 'package:differentworld/features/action_words/conductor.dart';
import 'package:differentworld/features/action_words/world_cast_game.dart';
import 'package:differentworld/features/live_board/board_game.dart';
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

    test('two ACTIVITIES have no script, on purpose', () {
      // Same ledger discipline as the games. Both are cases where a briefing
      // would work against the activity rather than for it.
      const noScript = {
        // Mindful Minute is a reset. Three beats of instruction before a
        // calming breath is the opposite of a calming breath — and the circle
        // teaches itself: the room breathes with it.
        '/activity/breathe': 'a calm reset explains itself by doing',
        // Photo Studio runs a pinned per-child session with its own turn
        // rules on screen; a second set of instructions in front of it would
        // compete with the ones the session already gives.
        '/activity/photo': 'the session already narrates its own turns',
      };
      for (final route in noScript.keys) {
        expect(activityRunScripts[route], isNull, reason: noScript[route]);
      }
    });

    test('the instruments have NO script, on purpose — and nothing else does', () {
      // The same shape as the grid-game ledger's `noEnding`: every exception
      // carries a written reason, so nobody later "fixes" it — and a game in
      // NEITHER list (no script, no reason) fails the build. That is what
      // turned "some games have instructions" into "every game a room can
      // play is one a substitute can start".
      final noScript = <String, String>{
        // Signals is an interruption — Eyes up, Freeze, Line up. A signal that
        // needs three taps of preamble is not a signal. The whole value is
        // that it lands the instant the adult reaches for it.
        'cues': 'it is an interruption, not an activity',
        // A countdown explains itself, and the adult reaching for it is
        // usually mid-transition with a room already moving.
        'timer': 'a clock needs no rules',
        // A sign, not a game: the day's schedule on the wall. Nobody plays it.
        'now-next': 'it is the schedule on the wall',
        // One button. "Tap Spin" is already on the stage.
        'picker': 'one button, and the stage says what it does',
        // The three cast-only instruments: driven from another screen, never
        // opened as an activity, so there is no room to brief.
        const BoardGame().id: 'an instrument the live board drives',
        const WorldCastGame().id: 'the world slideshow, cast from This Week',
        const ConductorGame().id: 'a text the conductor screen drives',
      };
      final actual = {
        for (final g in liveGames)
          if (g.howToPlay.isEmpty) g.id,
      };
      expect(
        actual,
        noScript.keys.toSet(),
        reason:
            'a game with no script needs a written reason here, and a game '
            'with a reason should not have grown a script',
      );
    });

    test('the ledger: how much of the deck a substitute could start', () {
      final withScript = liveGames.where((g) => g.howToPlay.isNotEmpty).length;
      // Deliberately an equality, not a floor. When the next batch lands this
      // test FAILS and the number gets updated — which is the point. A ">= 3"
      // would sit green forever while 38 games stayed unrunnable, and the
      // whole reason this feature exists is that nobody could see that gap.
      //
      // 34 = every game a room opens as an activity. The seven without are
      // the instruments in the ledger above.
      expect(
        withScript,
        34,
        reason:
            'Update this count as run-scripts land. $withScript of '
            '${liveGames.length} games can be started by someone who does '
            'not know the rules.',
      );
      // The activity half of the same ledger, and the same equality for the
      // same reason: a floor would sit green while the rest stayed unrunnable.
      expect(
        activityRunScripts.length,
        9,
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

    test('play again does NOT re-brief — the room just played', () {
      // Four taps of instructions between every round is the sign on a wall
      // the half-second rule warns about: people learn to tap through it,
      // and then tap through it the one time it matters. The rules stay one
      // tap away instead (below).
      var wire = seeded();
      for (var i = 0; i < g.howToPlay.length; i++) {
        wire = RunScriptWire.reduce(g, wire, GameIntent.next, const {});
      }
      expect(RunScriptWire.indexOf(wire), isNull);
      wire = RunScriptWire.reduce(g, wire, GameIntent.reset, const {});
      expect(RunScriptWire.indexOf(wire), isNull, reason: 'straight to a deal');
      expect(g.decode(wire).cells, isNotEmpty, reason: 'and it dealt');
    });

    test('the rules can be re-opened over a live board, and closed again', () {
      var wire = seeded();
      for (var i = 0; i < g.howToPlay.length; i++) {
        wire = RunScriptWire.reduce(g, wire, GameIntent.next, const {});
      }
      // Play a move, then ask for the rules.
      wire = RunScriptWire.reduce(g, wire, GameIntent.pick, {'cell': 0});
      final played = g.decode(wire);
      expect(played.cells.where((c) => c.face != null), hasLength(1));
      wire = RunScriptWire.reduce(g, wire, GameIntent.reveal, {
        RunScriptWire.rulesArg: true,
      });
      expect(RunScriptWire.indexOf(wire), 0, reason: 'beat one again');
      // The board underneath is untouched — Start returns to the same round.
      for (var i = 0; i < g.howToPlay.length; i++) {
        wire = RunScriptWire.reduce(g, wire, GameIntent.next, const {});
      }
      expect(RunScriptWire.indexOf(wire), isNull);
      expect(
        g.decode(wire).cells.where((c) => c.face != null),
        hasLength(1),
        reason: 'the move survived the glance at the rules',
      );
    });

    test('a plain reveal is NOT a rules request', () {
      var wire = seeded();
      for (var i = 0; i < g.howToPlay.length; i++) {
        wire = RunScriptWire.reduce(g, wire, GameIntent.next, const {});
      }
      wire = RunScriptWire.reduce(g, wire, GameIntent.reveal, const {});
      expect(RunScriptWire.indexOf(wire), isNull);
    });

    test('a game with no script ignores a rules request', () {
      const plain = TimerGame();
      final wire = plain.initialState(LocalContentBank.seeded());
      final after = RunScriptWire.reduce(plain, wire, GameIntent.reveal, {
        RunScriptWire.rulesArg: true,
      });
      expect(RunScriptWire.indexOf(after), isNull);
    });
  });
}
