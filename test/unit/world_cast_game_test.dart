import 'dart:convert';
import 'dart:io';

import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/world_cast_game.dart';
import 'package:differentworld/features/games/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// "Simulating the two devices": the controller and the receiver share ONE
/// pure wire-state + reducer. The controller calls `send(intent)` (the
/// authority reduces + rebroadcasts); the receiver `decode`s the same state.
/// So applying the reducer here reproduces exactly what crosses the wire —
/// the Realtime channel is the framework's already-proven transport.
void main() {
  CurriculumWorld worldByWeek(int week) {
    final raw = File('assets/curriculum/ten_worlds.json').readAsStringSync();
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    for (final w in decoded['worlds'] as List) {
      final cw = CurriculumWorld.fromJson(w as Map<String, dynamic>);
      if (cw.week == week) return cw;
    }
    throw StateError('no week $week');
  }

  const game = WorldCastGame();

  group('worldCastSeed', () {
    test('builds title + question + videos + verbs + activities', () {
      final space = worldByWeek(6); // World of Space — 3 videos
      final seed = worldCastSeed(space);
      // 1 title + 1 question + 3 watch + 1 verbs + 1 activities = 7
      expect(seed['n'], 7);
      expect(seed['i'], 0);
      final slides = (seed['slides'] as List).cast<Map<String, dynamic>>();
      expect(slides.first['k'], 'title');
      expect(slides[1]['k'], 'q');
      expect(slides.where((s) => s['k'] == 'watch').length, 3);
      expect(slides.any((s) => s['k'] == 'verbs'), isTrue);
      expect(slides.last['k'], 'acts');
      expect(seed['accent'], startsWith('#'));
    });
  });

  group('the slide state machine (what both devices run)', () {
    test('next advances and clamps at the last slide', () {
      var state = worldCastSeed(worldByWeek(1));
      final last = (state['n'] as int) - 1;
      for (var k = 0; k < last + 3; k++) {
        state = game.reduce(state, GameIntent.next, const {});
      }
      expect(game.decode(state).index, last); // clamped, never overruns
    });

    test('back rewinds and clamps at 0', () {
      var state = worldCastSeed(worldByWeek(1));
      state = game.reduce(state, GameIntent.next, const {});
      state = game.reduce(state, GameIntent.next, const {});
      expect(game.decode(state).index, 2);
      state = game.reduce(state, GameIntent.back, const {});
      expect(game.decode(state).index, 1);
      state = game.reduce(state, GameIntent.back, const {});
      state = game.reduce(state, GameIntent.back, const {});
      expect(game.decode(state).index, 0); // clamped
    });

    test('reset jumps back to the first slide', () {
      var state = worldCastSeed(worldByWeek(1));
      state = game.reduce(state, GameIntent.next, const {});
      state = game.reduce(state, GameIntent.next, const {});
      state = game.reduce(state, GameIntent.reset, const {});
      expect(game.decode(state).index, 0);
    });
  });

  group('activeIntents gate the control bar', () {
    test('no Back on the first slide, no Next on the last', () {
      final seed = worldCastSeed(worldByWeek(1));
      final first = game.decode(seed);
      expect(game.activeIntents(first).contains(GameIntent.back), isFalse);
      expect(game.activeIntents(first).contains(GameIntent.next), isTrue);

      var state = seed;
      for (var k = 0; k < first.total; k++) {
        state = game.reduce(state, GameIntent.next, const {});
      }
      final lastSlide = game.decode(state);
      expect(game.activeIntents(lastSlide).contains(GameIntent.next), isFalse);
      expect(game.activeIntents(lastSlide).contains(GameIntent.back), isTrue);
      // Reset is always available.
      expect(game.activeIntents(lastSlide).contains(GameIntent.reset), isTrue);
    });
  });

  group('receiver decode reflects the controller index', () {
    test('after the controller advances, the receiver shows that slide', () {
      // Controller side: build + advance twice.
      var wire = worldCastSeed(worldByWeek(6));
      wire = game.reduce(wire, GameIntent.next, const {});
      wire = game.reduce(wire, GameIntent.next, const {});
      // Receiver side: decode the SAME wire-state.
      final received = game.decode(wire);
      expect(received.index, 2);
      // Space week 6: slide 2 is the first 'watch' (title=0, q=1, watch=2).
      expect(received.current?['k'], 'watch');
    });

    test('decode is tolerant of an empty / malformed wire-state', () {
      final empty = game.decode(const {});
      expect(empty.index, 0);
      expect(empty.total, 0);
      expect(empty.current, isNull);
    });
  });

  group('the receiver renders the stage (what the room sees)', () {
    testWidgets('title slide shows the world; advancing shows the question', (
      tester,
    ) async {
      // The stage targets a TV / projector, not a phone — size the test
      // surface accordingly so the big hero text isn't overflow-clipped.
      tester.view.physicalSize = const Size(1600, 1000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final space = worldByWeek(6);
      var wire = worldCastSeed(space);

      Future<void> pump() => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => game.buildStage(ctx, game.decode(wire)),
            ),
          ),
        ),
      );

      await pump();
      expect(find.text('World of Space'), findsOneWidget);
      expect(find.text('WEEK 6'), findsOneWidget);

      // Controller advances to the question slide; receiver re-renders.
      wire = game.reduce(wire, GameIntent.next, const {});
      await pump();
      expect(find.text('“${space.question}”'), findsOneWidget);
    });
  });
}
