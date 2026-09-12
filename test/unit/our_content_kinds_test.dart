import 'package:differentworld/features/activity_runtime/content_bank.dart';
import 'package:differentworld/features/game_content/content_kinds.dart';
import 'package:differentworld/features/game_content/ours_strip.dart';
import 'package:flutter_test/flutter_test.dart';

/// The teeth behind docs/CONDITIONS.md: a content kind with no authoring door
/// is a condition the room cannot fill, which is the exact state the app was
/// in when `picture` had a library and the other fifteen kinds had nothing.
void main() {
  group('authorable kinds', () {
    test('every ContentKind has a door, or is deliberately exempt', () {
      // `picture` authors through the camera-shaped library at
      // /games/pictures — its payload is an upload, not typed fields.
      const exempt = {ContentKind.picture};
      final declared = <String>{
        ContentKind.thisOrThat,
        ContentKind.category,
        ContentKind.line,
        ContentKind.asIf,
        ContentKind.riddle,
        ContentKind.factOrFib,
        ContentKind.storyStarter,
        ContentKind.storyTwist,
        ContentKind.rhymeWord,
        ContentKind.charades,
        ContentKind.picture,
        ContentKind.doIt,
        ContentKind.question,
        ContentKind.quote,
        ContentKind.fillBlank,
        ContentKind.writePrompt,
        ContentKind.scavengerThing,
        ContentKind.fourCorners,
      };
      final withDoors = authorableKinds.map((s) => s.kind).toSet();
      expect(
        declared.difference(withDoors).difference(exempt),
        isEmpty,
        reason:
            'Every content kind needs a ContentKindSpec in authorableKinds so '
            'a room can write its own — see docs/CONDITIONS.md.',
      );
    });

    test('the check can actually fail', () {
      // A checker that cannot fail is worse than none, because it is believed.
      final withDoors = authorableKinds.map((s) => s.kind).toSet();
      expect(withDoors.contains('a_kind_nobody_declared'), isFalse);
    });

    test('no duplicate kinds, and every spec has fields', () {
      final kinds = authorableKinds.map((s) => s.kind).toList();
      expect(kinds.toSet().length, kinds.length);
      for (final spec in authorableKinds) {
        expect(spec.fields, isNotEmpty, reason: '${spec.kind} has no fields');
        expect(spec.one, isNotEmpty);
        expect(spec.many, isNotEmpty);
        expect(spec.blurb, isNotEmpty);
      }
    });

    test('summaryKey, when set, names a real field', () {
      for (final spec in authorableKinds) {
        final key = spec.summaryKey;
        if (key == null) continue;
        expect(
          spec.fields.map((f) => f.key),
          contains(key),
          reason: '${spec.kind} summarises on a key it has no field for',
        );
      }
    });
  });

  group('field keys match what the activities read', () {
    // These rows merge into the same bank the curated seeds live in, so a
    // mismatched key is a row the game silently skips — invisible until a
    // teacher wonders why their question never came up.
    const expected = {
      ContentKind.thisOrThat: {'a', 'b'},
      ContentKind.category: {'label'},
      ContentKind.line: {'text'},
      ContentKind.asIf: {'text'},
      ContentKind.riddle: {'prompt', 'answer'},
      ContentKind.factOrFib: {'statement', 'isTrue', 'note'},
      ContentKind.storyStarter: {'text'},
      ContentKind.storyTwist: {'text'},
      ContentKind.rhymeWord: {'word'},
      ContentKind.charades: {'word', 'category'},
      ContentKind.doIt: {'text', 'verb', 'emoji'},
      ContentKind.question: {'text'},
      ContentKind.quote: {'text', 'author'},
      ContentKind.fillBlank: {'template', 'blanks'},
      ContentKind.writePrompt: {'text'},
      ContentKind.scavengerThing: {'text'},
      ContentKind.fourCorners: {'question', 'a', 'b', 'c', 'd'},
    };

    test('each spec writes exactly the payload keys its seeds use', () {
      for (final spec in authorableKinds) {
        expect(
          spec.fields.map((f) => f.key).toSet(),
          expected[spec.kind],
          reason:
              '${spec.kind}: authored rows must carry the same keys as the '
              'curated seeds or the activity skips them.',
        );
      }
    });
  });

  group('summarize / detail', () {
    test('a well-formed payload reads as its headline', () {
      final spec = specForKind(ContentKind.thisOrThat)!;
      expect(spec.summarize({'a': 'Playground', 'b': 'Gym'}), 'Playground');
      expect(spec.detail({'a': 'Playground', 'b': 'Gym'}), 'Gym');
    });

    test('summaryKey overrides the first field', () {
      final spec = specForKind(ContentKind.riddle)!;
      expect(spec.summaryKey, 'prompt');
      expect(
        spec.summarize({'prompt': 'What has hands?', 'answer': 'A clock'}),
        'What has hands?',
      );
    });

    test('a malformed payload still renders something deletable', () {
      final spec = specForKind(ContentKind.thisOrThat)!;
      expect(spec.summarize(const {}), 'Untitled pair');
      expect(spec.summarize(const {'a': '   ', 'b': 'Gym'}), 'Gym');
    });

    test('a bool field reads as its label, not "true"', () {
      final spec = specForKind(ContentKind.factOrFib)!;
      expect(spec.detail({'statement': 'x', 'isTrue': true}), contains('Fact'));
      expect(spec.detail({'statement': 'x', 'isTrue': false}), contains('Fib'));
    });

    test('a list field joins rather than printing Dart syntax', () {
      final spec = specForKind(ContentKind.fillBlank)!;
      final detail = spec.detail({
        'template': 'a {0}',
        'blanks': ['an animal', 'an action'],
      });
      expect(detail, 'an animal · an action');
      expect(detail, isNot(contains('[')));
    });
  });

  group('activity → kind map', () {
    test('every mapped kind has a spec', () {
      for (final entry in activityAuthorKinds.entries) {
        for (final kind in entry.value) {
          expect(
            specForKind(kind),
            isNotNull,
            reason: '${entry.key} points at "$kind", which has no form',
          );
        }
      }
    });

    test('lookup works by route and by game id', () {
      expect(
        authorKindsFor('/activity/this-or-that'),
        contains(ContentKind.thisOrThat),
      );
      expect(authorKindsFor('this-or-that'), contains(ContentKind.thisOrThat));
      // The registry's one id/route mismatch.
      expect(authorKindsFor('letter-words'), contains(ContentKind.category));
      expect(authorKindsFor('nothing-like-this'), isEmpty);
    });
  });
}
