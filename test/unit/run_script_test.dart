import 'package:differentworld/features/games/game.dart';
import 'package:differentworld/features/games/game_registry.dart';
import 'package:differentworld/features/games/games/bingo_game.dart';
import 'package:differentworld/features/games/games/charades_game.dart';
import 'package:differentworld/features/games/games/connect_four_game.dart';
import 'package:flutter_test/flutter_test.dart';

/// The run-script exists so a SUBSTITUTE can start any activity by finding
/// Next. These pin the shape; the ledger at the bottom pins the honest count,
/// because "some games have instructions" is the state this is meant to leave
/// behind, not arrive at.
void main() {
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

    test('the ledger: how much of the deck a substitute could start', () {
      final withScript = liveGames.where((g) => g.howToPlay.isNotEmpty).length;
      // Deliberately an equality, not a floor. When the next batch lands this
      // test FAILS and the number gets updated — which is the point. A ">= 3"
      // would sit green forever while 38 games stayed unrunnable, and the
      // whole reason this feature exists is that nobody could see that gap.
      expect(
        withScript,
        3,
        reason:
            'Update this count as run-scripts land. $withScript of '
            '${liveGames.length} games can be started by someone who does '
            'not know the rules.',
      );
    });
  });
}
