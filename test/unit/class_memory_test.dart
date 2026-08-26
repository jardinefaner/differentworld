// Class memory is entries with a group and NO subject. These pin the two
// things that are easy to get quietly wrong: what counts as a class memory
// when reading rows back, and which one Return reaches for.

import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/class_memory/class_memory.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Entry row({
    required String id,
    String? body = 'Why do leaves go red?',
    String? sort = 'question',
    String? context,
    String recordedAt = '2026-08-01T10:00:00.000Z',
    String details = '',
  }) => Entry(
    id: id,
    spaceId: 'sp1',
    kind: 'class_memory',
    recordedBy: 'm1',
    groupId: 'g1',
    recordedAt: recordedAt,
    updatedAt: recordedAt,
    body: body,
    details: details.isNotEmpty
        ? details
        : jsonEncode({
            'sort': ?sort,
            'context': ?context,
          }),
  );

  group('reading a row back', () {
    test('a well-formed row becomes a memory', () {
      final m = ClassMemory.fromEntry(row(id: 'a'));
      expect(m, isNotNull);
      expect(m!.sort, ClassMemorySort.question);
      expect(m.text, 'Why do leaves go red?');
    });

    test('the timestamp is LOCAL, not the stored UTC', () {
      final m = ClassMemory.fromEntry(row(id: 'a'))!;
      final stored = DateTime.parse('2026-08-01T10:00:00.000Z');
      expect(m.recordedAt, stored.toLocal());
      expect(m.recordedAt!.isUtc, isFalse);
    });

    test('an unknown sort is SKIPPED, not guessed at', () {
      // A row written by a newer build carrying a fourth sort must not be
      // silently filed under one of the three this build knows.
      expect(ClassMemory.fromEntry(row(id: 'a', sort: 'prediction')), isNull);
    });

    test('a missing sort is skipped', () {
      expect(ClassMemory.fromEntry(row(id: 'a', sort: null)), isNull);
    });

    test('empty text is skipped — a memory with no words is not one', () {
      expect(ClassMemory.fromEntry(row(id: 'a', body: '   ')), isNull);
      expect(ClassMemory.fromEntry(row(id: 'a', body: null)), isNull);
    });

    test('malformed details do not throw', () {
      expect(ClassMemory.fromEntry(row(id: 'a', details: 'not json')), isNull);
    });

    test('blank context is dropped rather than rendered empty', () {
      final m = ClassMemory.fromEntry(row(id: 'a', context: '  '));
      expect(m!.context, isNull);
    });
  });

  group('grouping', () {
    test('every heading is present even when it has nothing in it', () {
      final grouped = groupBySort([ClassMemory.fromEntry(row(id: 'a'))!]);
      expect(grouped.keys, containsAll(ClassMemorySort.values));
      expect(grouped[ClassMemorySort.word], isEmpty);
    });
  });

  group('what Return reaches for', () {
    ClassMemory q(String id, String at) =>
        ClassMemory.fromEntry(row(id: id, recordedAt: at))!;

    test('the OLDEST open question, not the newest', () {
      // The whole design. A question from three weeks ago has had time to
      // become surprising again; one from this morning is still in the
      // room's head and returning it would be noise.
      final picked = oldestOpenQuestion([
        q('new', '2026-08-20T10:00:00.000Z'),
        q('old', '2026-08-01T10:00:00.000Z'),
        q('mid', '2026-08-10T10:00:00.000Z'),
      ]);
      expect(picked!.id, 'old');
    });

    test('discoveries and words are never returned as questions', () {
      final notQuestions = [
        ClassMemory.fromEntry(row(id: 'd', sort: 'discovery'))!,
        ClassMemory.fromEntry(row(id: 'w', sort: 'word'))!,
      ];
      expect(oldestOpenQuestion(notQuestions), isNull);
    });

    test('an empty room has nothing to return, and says nothing', () {
      expect(oldestOpenQuestion(const []), isNull);
    });
  });
}
