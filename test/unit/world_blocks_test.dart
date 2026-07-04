import 'dart:convert';
import 'dart:io';

import 'package:differentworld/features/action_words/world_blocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorldBlock.fromJson', () {
    test('parses meta, hex color, words, questions, and days', () {
      final b = WorldBlock.fromJson(const {
        'week': 4,
        'id': 'water',
        'name': 'World of Water',
        'emoji': '🌊',
        'color': '#4ABED9',
        'arrival': 'the room is blue',
        'room': 'blue everywhere',
        'soundtrack': 'ocean waves',
        'words': ['EVAPORATE', 'CURRENT'],
        'wallQuestions': ['where does water go?', 'what is the oldest water?'],
        'keyMoment': 'the food coloring drop',
        'transition': 'drain the water',
        'days': [
          {'day': 16, 'title': 'The Room Is Underwater', 'focus': 'pour water'},
          {'day': 17, 'title': 'The Water Cycle', 'focus': 'map the cycle'},
        ],
      });
      expect(b.week, 4);
      expect(b.id, 'water');
      expect(b.name, 'World of Water');
      expect(b.emoji, '🌊');
      expect(b.color.toARGB32(), 0xFF4ABED9);
      expect(b.words, ['EVAPORATE', 'CURRENT']);
      expect(b.wallQuestions.length, 2);
      expect(b.keyMoment, 'the food coloring drop');
      expect(b.days.first.day, 16);
      expect(b.days.last.title, 'The Water Cycle');
    });

    test('is tolerant of missing fields', () {
      final b = WorldBlock.fromJson(const {});
      expect(b.week, 0);
      expect(b.id, '');
      expect(b.name, '');
      expect(b.emoji, '🌍');
      expect(b.words, isEmpty);
      expect(b.wallQuestions, isEmpty);
      expect(b.days, isEmpty);
    });
  });

  group('the canonical world_blocks asset', () {
    // Read the real bundled JSON from disk (CWD = package root in tests),
    // parse with the real model, and validate the content is complete.
    late List<WorldBlock> worlds;

    setUpAll(() {
      final raw = File(
        'assets/curriculum/world_blocks.json',
      ).readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      worlds = [
        for (final b in decoded['worlds'] as List)
          WorldBlock.fromJson(b as Map<String, dynamic>),
      ]..sort((a, b) => a.week.compareTo(b.week));
    });

    test('is ten weekly worlds, weeks 1..10 unique', () {
      expect(worlds.length, 10);
      expect(worlds.map((w) => w.week).toList(), [
        1,
        2,
        3,
        4,
        5,
        6,
        7,
        8,
        9,
        10,
      ]);
      expect(worlds.first.id, 'me');
      expect(worlds.last.id, 'us');
    });

    test('every world has full environment + bank content', () {
      for (final w in worlds) {
        expect(w.arrival, isNotEmpty, reason: '${w.id} missing arrival');
        expect(w.room, isNotEmpty, reason: '${w.id} missing room');
        expect(w.soundtrack, isNotEmpty, reason: '${w.id} missing soundtrack');
        expect(w.keyMoment, isNotEmpty, reason: '${w.id} missing keyMoment');
        expect(w.transition, isNotEmpty, reason: '${w.id} missing transition');
        expect(w.words.length, 5, reason: '${w.id} not 5 words');
        expect(w.wallQuestions.length, 5, reason: '${w.id} not 5 wall qs');
        expect(w.days.length, 5, reason: '${w.id} not 5 days');
      }
    });

    test('days are numbered 1..50, unique and in order', () {
      final dayNumbers = [
        for (final w in worlds) ...w.days.map((d) => d.day),
      ];
      expect(dayNumbers, List.generate(50, (i) => i + 1));
    });

    test('every day has a title and a focus', () {
      for (final w in worlds) {
        for (final d in w.days) {
          expect(d.title, isNotEmpty, reason: 'day ${d.day} has no title');
          expect(d.focus, isNotEmpty, reason: 'day ${d.day} has no focus');
        }
      }
    });
  });

  group('blockForDay', () {
    // Ten weekly worlds of five days each (days 1-5, 6-10, … 46-50).
    final worlds = [
      for (var i = 0; i < 10; i++)
        WorldBlock.fromJson({
          'name': 'w$i',
          'days': [
            for (var d = 1; d <= 5; d++) {'day': i * 5 + d},
          ],
        }),
    ];

    test('maps each five-day window to its world', () {
      expect(blockForDay(worlds, 1)!.name, 'w0');
      expect(blockForDay(worlds, 5)!.name, 'w0');
      expect(blockForDay(worlds, 6)!.name, 'w1');
      expect(blockForDay(worlds, 11)!.name, 'w2');
      expect(blockForDay(worlds, 21)!.name, 'w4');
      expect(blockForDay(worlds, 50)!.name, 'w9');
    });

    test('clamps out-of-range days to the nearest world', () {
      expect(blockForDay(worlds, 0)!.name, 'w0');
      expect(blockForDay(worlds, -5)!.name, 'w0');
      expect(blockForDay(worlds, 99)!.name, 'w9');
    });

    test('empty list → null', () {
      expect(blockForDay(const [], 5), isNull);
    });
  });

  group('journeyDayForDay', () {
    final worlds = [
      WorldBlock.fromJson(const {
        'name': 'a',
        'days': [
          {'day': 1, 'title': 'one'},
          {'day': 2, 'title': 'two'},
        ],
      }),
      WorldBlock.fromJson(const {
        'name': 'b',
        'days': [
          {'day': 6, 'title': 'six'},
        ],
      }),
    ];

    test('finds the exact day across worlds', () {
      expect(journeyDayForDay(worlds, 2)!.title, 'two');
      expect(journeyDayForDay(worlds, 6)!.title, 'six');
    });

    test('null when no day matches', () {
      expect(journeyDayForDay(worlds, 5), isNull);
      expect(journeyDayForDay(const [], 1), isNull);
    });
  });

  group('wallQuestionForDay', () {
    final worlds = [
      WorldBlock.fromJson({
        'name': 'a',
        'wallQuestions': [for (var i = 0; i < 5; i++) 'a$i'],
        'days': [
          for (var d = 1; d <= 5; d++) {'day': d},
        ],
      }),
      WorldBlock.fromJson({
        'name': 'b',
        'wallQuestions': [for (var i = 0; i < 5; i++) 'b$i'],
        'days': [
          for (var d = 6; d <= 10; d++) {'day': d},
        ],
      }),
    ];

    test('first day of a world → first question', () {
      expect(wallQuestionForDay(worlds, 1), 'a0');
      expect(wallQuestionForDay(worlds, 6), 'b0');
    });

    test('last day of a world → fifth question', () {
      expect(wallQuestionForDay(worlds, 5), 'a4');
      expect(wallQuestionForDay(worlds, 10), 'b4');
    });

    test('null when the world has no questions / empty list', () {
      final noQ = [
        WorldBlock.fromJson(const {'name': 'x'}),
      ];
      expect(wallQuestionForDay(noQ, 1), isNull);
      expect(wallQuestionForDay(const [], 1), isNull);
    });
  });

  group('programDayFor', () {
    // 2026-06-01 is a Monday — Week-1 day 1 of the journey. Anchored in summer
    // (when the program actually runs) so the 50-day span never crosses a DST
    // boundary, keeping the Duration arithmetic deterministic.
    final monday = DateTime(2026, 6);
    assert(monday.weekday == DateTime.monday, '2026-06-01 must be a Monday');

    test('null start → not active', () {
      expect(programDayFor(null, monday), isNull);
    });

    test('start day (Monday) → day 1', () {
      expect(programDayFor(monday, monday), 1);
    });

    test('weekdays within week 1 → days 1..5', () {
      for (var i = 0; i < 5; i++) {
        expect(programDayFor(monday, monday.add(Duration(days: i))), i + 1);
      }
    });

    test('weekend clamps to Friday (day 5)', () {
      expect(programDayFor(monday, monday.add(const Duration(days: 5))), 5);
      expect(programDayFor(monday, monday.add(const Duration(days: 6))), 5);
    });

    test('week 2 Monday → day 6', () {
      expect(programDayFor(monday, monday.add(const Duration(days: 7))), 6);
    });

    test('week 10 Friday → day 50', () {
      expect(programDayFor(monday, monday.add(const Duration(days: 67))), 50);
    });

    test('past week 10 → not active', () {
      expect(
        programDayFor(monday, monday.add(const Duration(days: 70))),
        isNull,
      );
    });

    test('before the start date → not active', () {
      expect(
        programDayFor(monday, monday.subtract(const Duration(days: 1))),
        isNull,
      );
    });

    test('every active weekday lands a valid 1..50 day in the right world', () {
      final worlds = [
        for (var i = 0; i < 10; i++)
          WorldBlock.fromJson({
            'name': 'w$i',
            'days': [
              for (var d = 1; d <= 5; d++) {'day': i * 5 + d},
            ],
          }),
      ];
      for (var offset = 0; offset <= 67; offset++) {
        final day = programDayFor(monday, monday.add(Duration(days: offset)));
        if (day == null) continue;
        expect(day, inInclusiveRange(1, 50));
        expect(blockForDay(worlds, day), isNotNull);
      }
    });
  });
}
