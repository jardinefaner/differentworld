// Pins the Action Words engine (docs/ACTION_WORDS.md): the world lookup
// (exact / closest / fresh, order-independent), the per-day parse, and the
// collection aggregation + emerging title.

import 'dart:convert';

import 'package:differentworld/core/db/app_database.dart';
import 'package:differentworld/features/action_words/action_words_providers.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:differentworld/features/action_words/worlds.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _dayEntry({
  required List<String> picks,
  List<String> done = const [],
  String? note,
  String? word,
  String? worldName,
  String recordedAt = '2026-06-06T15:00:00Z',
}) {
  final details = <String, dynamic>{
    'verb_picks': picks,
    'done': done,
    'note': ?note,
    'word_of_day': ?word,
    'world_name': ?worldName,
  };
  return Entry(
    id: 'aw-$recordedAt',
    spaceId: 's1',
    kind: 'action_words',
    details: jsonEncode(details),
    recordedBy: 'm1',
    recordedAt: recordedAt,
    updatedAt: recordedAt,
    subjectId: 'kid1',
  );
}

void main() {
  group('the 12 verbs', () {
    test('exist, are unique, and resolve by id', () {
      expect(kVerbs.length, 12);
      expect(kVerbs.map((v) => v.id).toSet().length, 12);
      expect(verbById('listen')?.label, 'Listen');
      expect(verbById('nope'), isNull);
      expect(kPicksPerDay, 3);
    });
  });

  group('worlds integrity', () {
    test('every named world has 3 distinct verbs, no duplicate combos', () {
      debugCheckWorlds(); // throws on a bad/duplicate combo
      for (final w in kNamedWorlds) {
        expect(w.verbs.length, 3, reason: w.id);
        for (final v in w.verbs) {
          expect(verbById(v), isNotNull, reason: '${w.id} uses unknown $v');
        }
      }
    });
  });

  group('matchWorld', () {
    test('an exact named combo resolves exactly (order-independent)', () {
      final a = matchWorld({'carry', 'help', 'listen'});
      expect(a.kind, WorldMatchKind.exact);
      expect(a.world?.id, 'ant');

      // Same combo, different order → same world.
      final b = matchWorld({'listen', 'carry', 'help'});
      expect(b.kind, WorldMatchKind.exact);
      expect(b.world?.id, 'ant');
    });

    test('a 2-verb-overlap combo resolves to a named closest world', () {
      // Shares {wait, watch} with Owl (listen/wait/watch).
      final m = matchWorld({'wait', 'watch', 'spark'});
      expect(m.kind, WorldMatchKind.closest);
      expect(m.isNamed, isTrue);
    });

    test('a <2-overlap combo is a fresh world (no named match)', () {
      // carry+echo+solve shares at most 1 verb with any named world.
      final m = matchWorld({'carry', 'echo', 'solve'});
      expect(m.kind, WorldMatchKind.fresh);
      expect(m.world, isNull);
      expect(m.isNamed, isFalse);
    });
  });

  group('ActionWordsDay', () {
    test('parses picks/done/note/word and derives the world', () {
      final day = ActionWordsDay.fromEntry(
        _dayEntry(
          picks: ['watch', 'spark', 'shine'],
          done: ['watch', 'spark'],
          note: 'Great focus today.',
          word: 'curious',
        ),
      );
      expect(day.hasPicks, isTrue);
      expect(day.doneCount, 2);
      expect(day.isComplete, isFalse);
      expect(day.note, 'Great focus today.');
      expect(day.wordOfDay, 'curious');
      expect(day.world?.world?.id, 'eagle'); // watch+spark+shine
    });

    test('no entry → empty day, no world', () {
      const day = ActionWordsDay(
        entry: null,
        verbPicks: [],
        done: {},
        note: null,
        wordOfDay: null,
        worldName: null,
      );
      expect(day.hasPicks, isFalse);
      expect(day.world, isNull);
    });
  });

  group('ActionWordsCollection', () {
    test('aggregates worlds + practiced verbs and forms the title', () {
      final c = ActionWordsCollection.fromEntries([
        _dayEntry(
          picks: ['listen', 'wait', 'watch'], // Owl
          done: ['listen', 'wait', 'watch'],
          recordedAt: '2026-06-04T15:00:00Z',
        ),
        _dayEntry(
          picks: ['listen', 'wait', 'watch'], // Owl again
          done: ['listen'],
          recordedAt: '2026-06-05T15:00:00Z',
        ),
        _dayEntry(
          picks: ['carry', 'help', 'listen'], // Ant (default date)
          done: ['listen'],
        ),
      ]);
      expect(c.dayCount, 3);
      expect(c.worldCounts['owl'], 2);
      expect(c.worldCounts['ant'], 1);
      expect(c.topWorldId, 'owl');
      // listen practiced all 3 days → top verb.
      expect(c.topVerbId, 'listen');
      expect(c.emergingTitle, 'The Owl Who Listens');
    });

    test('a day with no picks is ignored', () {
      final c = ActionWordsCollection.fromEntries([
        _dayEntry(picks: ['only', 'two']),
      ]);
      expect(c.dayCount, 0);
      expect(c.emergingTitle, isNull);
    });
  });
}
