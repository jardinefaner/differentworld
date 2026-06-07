import 'package:differentworld/features/action_words/conductor.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const game = ConductorGame();

  group('parseLyrics + seed', () {
    test('splits lines into words, drops blank lines', () {
      final lines = parseLyrics('Twinkle twinkle\n\nlittle star');
      expect(lines, [
        ['Twinkle', 'twinkle'],
        ['little', 'star'],
      ]);
    });

    test('seed starts with nothing lit', () {
      final seed = conductorSeed('a b c');
      expect(seed['i'], -1);
      expect(game.decode(seed).total, 3);
    });
  });

  group('the conducting state machine (both devices)', () {
    test('tap a word lights exactly that word', () {
      var s = conductorSeed('one two three four');
      s = game.reduce(s, GameIntent.pick, const {'i': 2});
      expect(game.decode(s).active, 2); // "three"
      // Tap another — the spotlight moves.
      s = game.reduce(s, GameIntent.pick, const {'i': 0});
      expect(game.decode(s).active, 0);
    });

    test('out-of-range taps clamp', () {
      var s = conductorSeed('one two');
      s = game.reduce(s, GameIntent.pick, const {'i': 99});
      expect(game.decode(s).active, 1); // last word
    });

    test('next walks forward from nothing; clear resets', () {
      var s = conductorSeed('one two three');
      s = game.reduce(s, GameIntent.next, const {}); // -1 -> 0
      expect(game.decode(s).active, 0);
      s = game.reduce(s, GameIntent.next, const {});
      expect(game.decode(s).active, 1);
      s = game.reduce(s, GameIntent.reset, const {});
      expect(game.decode(s).active, -1);
    });

    test('back steps down then clears the spotlight', () {
      var s = conductorSeed('one two three');
      s = game.reduce(s, GameIntent.pick, const {'i': 1});
      s = game.reduce(s, GameIntent.back, const {});
      expect(game.decode(s).active, 0);
      s = game.reduce(s, GameIntent.back, const {});
      expect(game.decode(s).active, -1); // cleared
    });
  });

  group('the receiver renders the lit word', () {
    testWidgets('the tapped word shows; the rest stay on screen too',
        (tester) async {
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var wire = conductorSeed('wash your hands');
      // Controller taps "hands" (index 2).
      wire = game.reduce(wire, GameIntent.pick, const {'i': 2});

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => game.buildStage(ctx, game.decode(wire)),
            ),
          ),
        ),
      );
      // All three words remain on the stage; "hands" is the lit one.
      expect(find.text('wash'), findsOneWidget);
      expect(find.text('your'), findsOneWidget);
      expect(find.text('hands'), findsOneWidget);
    });
  });
}
