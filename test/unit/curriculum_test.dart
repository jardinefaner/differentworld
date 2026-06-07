import 'dart:convert';
import 'dart:io';

import 'package:differentworld/features/action_words/curriculum.dart';
import 'package:differentworld/features/action_words/themed_worlds.dart';
import 'package:differentworld/features/action_words/verbs.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CurriculumWorld.fromJson', () {
    test('parses meta, hex color, facets, verbs, and videos', () {
      final w = CurriculumWorld.fromJson(const {
        'week': 4,
        'id': 'water',
        'name': 'World of Water',
        'emoji': '🌊',
        'color': '#4ABED9',
        'tagline': 'old water',
        'question': 'where would you go?',
        'facets': {'people': 'rivers and rain', 'map': 'the plumbing'},
        'featuredVerbs': ['flow', 'solve', 'echo'],
        'verbsNote': 'FLOW…',
        'activities': ['ice race', 'water xylophone'],
        'videos': [
          {'title': 'water cycle', 'minutes': 3, 'after': 'act it out'},
        ],
      });
      expect(w.week, 4);
      expect(w.id, 'water');
      expect(w.color.toARGB32(), 0xFF4ABED9);
      expect(w.facets['people'], 'rivers and rain');
      expect(w.featuredVerbs, ['flow', 'solve', 'echo']);
      expect(w.activities.length, 2);
      expect(w.videos.single.minutes, 3);
      expect(w.videos.single.after, 'act it out');
    });

    test('is tolerant of missing fields', () {
      final w = CurriculumWorld.fromJson(const {});
      expect(w.week, 0);
      expect(w.facets, isEmpty);
      expect(w.featuredVerbs, isEmpty);
      expect(w.videos, isEmpty);
    });
  });

  group('the canonical curriculum asset', () {
    // Read the real bundled JSON from disk (CWD = package root in tests),
    // parse with the real model, and validate the content is complete.
    late List<CurriculumWorld> worlds;

    setUpAll(() {
      final raw = File('assets/curriculum/ten_worlds.json').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      worlds = [
        for (final w in decoded['worlds'] as List)
          CurriculumWorld.fromJson(w as Map<String, dynamic>),
      ]..sort((a, b) => a.week.compareTo(b.week));
    });

    test('is the 10-week journey, weeks 1..10 unique', () {
      expect(worlds.length, 10);
      expect(worlds.map((w) => w.week).toList(),
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(worlds.first.id, 'me');
      expect(worlds.last.id, 'us');
    });

    test('every world has all ten facets with content', () {
      final facetIds = kWorldFacets.map((f) => f.id).toSet();
      for (final w in worlds) {
        for (final id in facetIds) {
          expect(w.facets[id], isNotNull,
              reason: '${w.id} missing facet $id');
          expect(w.facets[id], isNotEmpty,
              reason: '${w.id} empty facet $id');
        }
      }
    });

    test('every featured verb is one of the 12 real verbs', () {
      for (final w in worlds) {
        expect(w.featuredVerbs, isNotEmpty, reason: '${w.id} has no verbs');
        for (final id in w.featuredVerbs) {
          expect(verbById(id), isNotNull,
              reason: '${w.id} references unknown verb "$id"');
        }
      }
    });

    test('every world has activities and Watch→Do videos', () {
      for (final w in worlds) {
        expect(w.activities, isNotEmpty, reason: '${w.id} has no activities');
        expect(w.videos, isNotEmpty, reason: '${w.id} has no videos');
        for (final v in w.videos) {
          expect(v.title, isNotEmpty);
          expect(v.after, isNotEmpty);
          expect(v.minutes, greaterThan(0));
        }
      }
    });
  });
}
