// The Group Discussions library (docs/VISION.md dream #6). Curated,
// kid-safe starters tagged by topic + age band; filtered by helpers the
// runner uses. No right answer, no generation — a plain catalog for now.

import 'package:differentworld/features/activity_runtime/discussions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('discussionLibrary', () {
    test('is non-empty with unique fingerprints', () {
      expect(discussionLibrary, isNotEmpty);
      final fps = discussionLibrary.map((d) => d.fingerprint).toSet();
      expect(fps, hasLength(discussionLibrary.length), reason: 'unique prompts');
    });

    test('every prompt has a known topic, a non-empty band set, real text', () {
      final topicIds = discussionTopics.map((t) => t.id).toSet();
      for (final d in discussionLibrary) {
        expect(d.prompt.trim(), isNotEmpty);
        expect(d.bands, isNotEmpty, reason: '${d.prompt} bands');
        expect(topicIds, contains(d.topicId), reason: '${d.prompt} topic');
        if (d.deeper != null) {
          expect(d.deeper!.trim(), isNotEmpty);
        }
      }
    });

    test('every topic shelf has at least one prompt', () {
      for (final t in discussionTopics) {
        expect(
          discussionLibrary.any((d) => d.topicId == t.id),
          isTrue,
          reason: '${t.label} has content',
        );
      }
    });
  });

  group('discussionsFor', () {
    test('only returns prompts that suit the requested band', () {
      for (final band in DiscussionBand.values) {
        final got = discussionsFor(band);
        expect(got, isNotEmpty, reason: '${band.label} has prompts');
        expect(got.every((d) => d.bands.contains(band)), isTrue);
      }
    });

    test('topic filter narrows to that single topic', () {
      final got = discussionsFor(DiscussionBand.middle, topicId: 'friendship');
      expect(got, isNotEmpty);
      expect(got.every((d) => d.topicId == 'friendship'), isTrue);
      expect(got.every((d) => d.bands.contains(DiscussionBand.middle)), isTrue);
    });
  });

  group('topicsFor / topicById', () {
    test('topicsFor never offers an empty shelf', () {
      for (final band in DiscussionBand.values) {
        for (final t in topicsFor(band)) {
          expect(
            discussionsFor(band, topicId: t.id),
            isNotEmpty,
            reason: '${t.label} for ${band.label}',
          );
        }
      }
    });

    test('topicById resolves known ids and null otherwise', () {
      expect(topicById('friendship')?.label, 'Friendship');
      expect(topicById('not-a-topic'), isNull);
    });
  });
}
