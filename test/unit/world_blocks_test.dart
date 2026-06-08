import 'dart:convert';
import 'dart:io';

import 'package:differentworld/features/action_words/world_blocks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorldBlock.fromJson', () {
    test('parses meta, hex color, words, questions, and days', () {
      final b = WorldBlock.fromJson(const {
        'name': 'World of Water',
        'emoji': '🌊',
        'color': '#4ABED9',
        'weeks': '5-6',
        'arrival': 'the room is blue',
        'room': 'blue everywhere',
        'soundtrack': 'ocean waves',
        'words': ['EVAPORATE', 'CURRENT'],
        'wallQuestions': ['where does water go?', 'what is the oldest water?'],
        'keyMoment': 'the food coloring drop',
        'transition': 'drain the water',
        'days': [
          {'day': 21, 'title': 'The Room Is Underwater', 'focus': 'pour water'},
          {'day': 22, 'title': 'The Water Cycle', 'focus': 'map the cycle'},
        ],
      });
      expect(b.name, 'World of Water');
      expect(b.emoji, '🌊');
      expect(b.color.toARGB32(), 0xFF4ABED9);
      expect(b.weeks, '5-6');
      expect(b.words, ['EVAPORATE', 'CURRENT']);
      expect(b.wallQuestions.length, 2);
      expect(b.keyMoment, 'the food coloring drop');
      expect(b.days.first.day, 21);
      expect(b.days.last.title, 'The Water Cycle');
    });

    test('is tolerant of missing fields', () {
      final b = WorldBlock.fromJson(const {});
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
    late List<WorldBlock> blocks;

    setUpAll(() {
      final raw = File('assets/curriculum/world_blocks.json').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      blocks = [
        for (final b in decoded['blocks'] as List)
          WorldBlock.fromJson(b as Map<String, dynamic>),
      ];
    });

    test('is five two-week blocks', () {
      expect(blocks.length, 5);
      expect(blocks.first.name, 'World of Me');
      expect(blocks.last.name, 'World of Feelings + Us');
    });

    test('every block has full environment + bank content', () {
      for (final b in blocks) {
        expect(b.arrival, isNotEmpty, reason: '${b.name} missing arrival');
        expect(b.room, isNotEmpty, reason: '${b.name} missing room');
        expect(b.soundtrack, isNotEmpty, reason: '${b.name} missing soundtrack');
        expect(b.keyMoment, isNotEmpty, reason: '${b.name} missing keyMoment');
        expect(b.transition, isNotEmpty, reason: '${b.name} missing transition');
        expect(b.words.length, 5, reason: '${b.name} not 5 words');
        expect(b.wallQuestions.length, 10,
            reason: '${b.name} not 10 wall questions');
        expect(b.days.length, 10, reason: '${b.name} not 10 days');
      }
    });

    test('days are numbered 1..50, unique and in order', () {
      final dayNumbers = [
        for (final b in blocks) ...b.days.map((d) => d.day),
      ];
      expect(dayNumbers, List.generate(50, (i) => i + 1));
    });

    test('every day has a title and a focus', () {
      for (final b in blocks) {
        for (final d in b.days) {
          expect(d.title, isNotEmpty, reason: 'day ${d.day} has no title');
          expect(d.focus, isNotEmpty, reason: 'day ${d.day} has no focus');
        }
      }
    });
  });

  group('blockForDay', () {
    final blocks = [
      for (var i = 0; i < 5; i++)
        WorldBlock.fromJson({
          'name': 'block$i',
          'days': [
            for (var d = 1; d <= 10; d++) {'day': i * 10 + d},
          ],
        }),
    ];

    test('maps each ten-day window to its block', () {
      expect(blockForDay(blocks, 1)!.name, 'block0');
      expect(blockForDay(blocks, 10)!.name, 'block0');
      expect(blockForDay(blocks, 11)!.name, 'block1');
      expect(blockForDay(blocks, 30)!.name, 'block2');
      expect(blockForDay(blocks, 41)!.name, 'block4');
      expect(blockForDay(blocks, 50)!.name, 'block4');
    });

    test('clamps out-of-range days to the nearest block', () {
      expect(blockForDay(blocks, 0)!.name, 'block0');
      expect(blockForDay(blocks, -5)!.name, 'block0');
      expect(blockForDay(blocks, 99)!.name, 'block4');
    });

    test('empty list → null', () {
      expect(blockForDay(const [], 5), isNull);
    });
  });

  group('journeyDayForDay', () {
    final blocks = [
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
          {'day': 11, 'title': 'eleven'},
        ],
      }),
    ];

    test('finds the exact day across blocks', () {
      expect(journeyDayForDay(blocks, 2)!.title, 'two');
      expect(journeyDayForDay(blocks, 11)!.title, 'eleven');
    });

    test('null when no day matches', () {
      expect(journeyDayForDay(blocks, 5), isNull);
      expect(journeyDayForDay(const [], 1), isNull);
    });
  });

  group('wallQuestionForDay', () {
    final blocks = [
      WorldBlock.fromJson({
        'name': 'a',
        'wallQuestions': [for (var i = 0; i < 10; i++) 'a$i'],
        'days': [
          for (var d = 1; d <= 10; d++) {'day': d},
        ],
      }),
      WorldBlock.fromJson({
        'name': 'b',
        'wallQuestions': [for (var i = 0; i < 10; i++) 'b$i'],
        'days': [
          for (var d = 11; d <= 20; d++) {'day': d},
        ],
      }),
    ];

    test('first day of a block → first question', () {
      expect(wallQuestionForDay(blocks, 1), 'a0');
      expect(wallQuestionForDay(blocks, 11), 'b0');
    });

    test('last day of a block → tenth question', () {
      expect(wallQuestionForDay(blocks, 10), 'a9');
      expect(wallQuestionForDay(blocks, 20), 'b9');
    });

    test('null when the block has no questions / empty list', () {
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
      expect(programDayFor(monday, monday.add(const Duration(days: 70))), isNull);
    });

    test('before the start date → not active', () {
      expect(programDayFor(monday, monday.subtract(const Duration(days: 1))),
          isNull);
    });

    test('every active weekday lands a valid 1..50 day in the right block', () {
      final blocks = [
        for (var i = 0; i < 5; i++)
          WorldBlock.fromJson({
            'name': 'block$i',
            'days': [
              for (var d = 1; d <= 10; d++) {'day': i * 10 + d},
            ],
          }),
      ];
      for (var offset = 0; offset <= 67; offset++) {
        final day = programDayFor(monday, monday.add(Duration(days: offset)));
        if (day == null) continue;
        expect(day, inInclusiveRange(1, 50));
        expect(blockForDay(blocks, day), isNotNull);
      }
    });
  });
}
