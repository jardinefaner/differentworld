// The procedural content engine — combinatorial generators + the cross-open
// "never-repeat" memory + the ContentSource routing.

import 'dart:math';

import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/activity_runtime/content_engine.dart';
import 'package:differentworld/features/activity_runtime/content_generators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('generators', () {
    test('the registry covers story + this-or-that with a big space', () {
      expect(contentGenerators.containsKey(ContentKind.storyStarter), isTrue);
      expect(contentGenerators.containsKey(ContentKind.thisOrThat), isTrue);
      // 12 × 18 × 24 × 10 × 20 = 1,036,800 distinct openers.
      expect(contentSpaceFor(ContentKind.storyStarter), greaterThan(1000000));
      // Σ C(theme,2) over the themed pools.
      expect(contentSpaceFor(ContentKind.thisOrThat), greaterThan(100));
      expect(contentSpaceFor(ContentKind.riddle), isNull); // authored, no gen
    });

    test('TemplateGenerator yields n distinct items with text', () {
      final gen = contentGenerators[ContentKind.storyStarter]!;
      final items = gen.generate(20, Random(1));
      expect(items.length, 20);
      expect(items.map((i) => i.fingerprint).toSet().length, 20); // distinct
      expect(items.first.payload['text']! as String, isNotEmpty);
    });

    test('a generator honours the exclude set', () {
      final gen = contentGenerators[ContentKind.storyStarter]!;
      final first = gen.generate(10, Random(2));
      final exclude = {
        for (final i in first) '${i.kind}/${i.fingerprint}',
      };
      final second = gen.generate(10, Random(3), exclude: exclude);
      // None of the second batch repeats the first (huge space → easy).
      for (final i in second) {
        expect(exclude.contains('${i.kind}/${i.fingerprint}'), isFalse);
      }
    });

    test('PairGenerator pairs are distinct, two-from-one-theme', () {
      final gen = contentGenerators[ContentKind.thisOrThat]!;
      final items = gen.generate(30, Random(4));
      for (final i in items) {
        expect(i.payload['a'], isNot(equals(i.payload['b'])));
      }
      expect(items.map((i) => i.fingerprint).toSet().length, items.length);
    });
  });

  group('ContentEngine', () {
    test('routes a generated kind to its generator', () {
      final engine = ContentEngine(
        curatedSeeds,
        memory: ContentMemory(),
        random: Random(1),
      );
      final story = engine.take(ContentKind.storyStarter, 8);
      expect(story.length, 8);
      expect(story.map((i) => i.fingerprint).toSet().length, 8); // distinct
    });

    test('an authored kind serves the curated pool, no in-session repeat', () {
      final engine = ContentEngine(
        curatedSeeds,
        memory: ContentMemory(),
        random: Random(1),
      );
      final a = engine.take(ContentKind.riddle, 5);
      final b = engine.take(ContentKind.riddle, 5);
      final seen = {
        ...a.map((i) => i.fingerprint),
        ...b.map((i) => i.fingerprint),
      };
      expect(seen.length, a.length + b.length); // no overlap across two takes
    });

    test('cross-open memory serves UNSEEN items first next time', () {
      final mem = ContentMemory();
      final pool = [
        for (var k = 0; k < 4; k++)
          ContentItem(
            kind: ContentKind.riddle,
            fingerprint: 'r$k',
            payload: {'prompt': 'q$k', 'answer': 'a$k'},
          ),
      ];
      // First open: 2 served + recorded into the shared memory.
      final first = ContentEngine(
        pool,
        generators: const {},
        memory: mem,
        random: Random(1),
      ).take(ContentKind.riddle, 2);
      final firstFps = first.map((i) => i.fingerprint).toSet();
      // Second open (new engine, SAME memory): the 2 unseen come first.
      final second = ContentEngine(
        pool,
        generators: const {},
        memory: mem,
        random: Random(9),
      ).take(ContentKind.riddle, 2);
      final secondFps = second.map((i) => i.fingerprint).toSet();
      // The two NOT shown first time should both appear now.
      final unseen = pool
          .where((i) => !firstFps.contains(i.fingerprint))
          .map((i) => i.fingerprint)
          .toSet();
      expect(secondFps, equals(unseen));
    });
  });

  group('ContentMemory', () {
    test('records recent fingerprints, capped', () {
      final mem = ContentMemory(cap: 3);
      for (var k = 0; k < 5; k++) {
        mem.record('k', 'fp$k');
      }
      final recent = mem.recent('k');
      expect(recent.length, 3); // capped
      expect(recent.contains('fp4'), isTrue); // newest kept
      expect(recent.contains('fp0'), isFalse); // oldest evicted
    });
  });
}
