import 'dart:convert';
import 'dart:io';

import 'package:differentworld/features/action_words/world_arc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorldArc.fromJson', () {
    test('parses week, id, missions, and rpg', () {
      final a = WorldArc.fromJson(const {
        'week': 5,
        'id': 'music',
        'missions': {
          'daily': ['find a rhythm', 'hum a feeling'],
          'weekly': ['build an instrument'],
          'project': 'the room song',
        },
        'rpg': {
          'avatar': 'music form',
          'name': 'The Drum',
          'spells': 'RHYTHM, MELODY',
          'tools': 'your body',
          'inventory': 'an instrument',
          'allies': 'call and response',
          'lore': 'where does a sound go',
          'weather': 'mood as soundtrack',
        },
      });
      expect(a.week, 5);
      expect(a.id, 'music');
      expect(a.missions.daily, ['find a rhythm', 'hum a feeling']);
      expect(a.missions.weekly.single, 'build an instrument');
      expect(a.missions.project, 'the room song');
      expect(a.rpg.spells, 'RHYTHM, MELODY');
      expect(a.rpg.name, 'The Drum');
    });

    test('is tolerant of missing fields', () {
      final a = WorldArc.fromJson(const {});
      expect(a.week, 0);
      expect(a.id, '');
      expect(a.missions.daily, isEmpty);
      expect(a.rpg.avatar, '');
    });
  });

  group('the canonical world_arc asset', () {
    late List<WorldArc> arcs;

    setUpAll(() {
      final raw = File('assets/curriculum/world_arc.json').readAsStringSync();
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      arcs = [
        for (final w in decoded['worlds'] as List)
          WorldArc.fromJson(w as Map<String, dynamic>),
      ]..sort((a, b) => a.week.compareTo(b.week));
    });

    test('is ten weekly worlds, weeks 1..10 unique', () {
      expect(arcs.length, 10);
      expect(arcs.map((a) => a.week).toList(),
          [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      expect(arcs.first.id, 'me');
      expect(arcs.last.id, 'us');
    });

    test('ids match the canonical weekly worlds', () {
      expect(
        arcs.map((a) => a.id).toList(),
        ['me', 'stories', 'nature', 'water', 'music', 'space', 'dreams',
            'time', 'feelings', 'us'],
      );
    });

    test('every world has full missions + rpg content', () {
      for (final a in arcs) {
        expect(a.missions.daily.length, greaterThanOrEqualTo(8),
            reason: '${a.id} thin on daily missions');
        expect(a.missions.weekly, isNotEmpty, reason: '${a.id} no weekly');
        expect(a.missions.project, isNotEmpty, reason: '${a.id} no project');
        for (final field in [
          a.rpg.avatar,
          a.rpg.name,
          a.rpg.spells,
          a.rpg.tools,
          a.rpg.inventory,
          a.rpg.allies,
          a.rpg.lore,
          a.rpg.weather,
        ]) {
          expect(field, isNotEmpty, reason: '${a.id} missing an rpg field');
        }
      }
    });
  });

  group('dailyMissionsForDay', () {
    final daily = [for (var i = 0; i < 10; i++) 'm$i'];

    test('returns count missions, rotating across days', () {
      expect(dailyMissionsForDay(daily, 1), ['m0', 'm1', 'm2']);
      expect(dailyMissionsForDay(daily, 2), ['m3', 'm4', 'm5']);
      expect(dailyMissionsForDay(daily, 3), ['m6', 'm7', 'm8']);
      // Day 4 wraps the window around the pool.
      expect(dailyMissionsForDay(daily, 4), ['m9', 'm0', 'm1']);
    });

    test('count is clamped to the pool; empty pool → empty', () {
      expect(dailyMissionsForDay(['a', 'b'], 1, count: 5).length, 2);
      expect(dailyMissionsForDay(const [], 1), isEmpty);
    });
  });

  group('arcForWeek', () {
    final arcs = [
      for (var w = 1; w <= 10; w++)
        WorldArc.fromJson({'week': w, 'id': 'w$w'}),
    ];

    test('finds the world for a week', () {
      expect(arcForWeek(arcs, 1)!.id, 'w1');
      expect(arcForWeek(arcs, 5)!.id, 'w5');
      expect(arcForWeek(arcs, 10)!.id, 'w10');
    });

    test('null when out of range / empty', () {
      expect(arcForWeek(arcs, 11), isNull);
      expect(arcForWeek(const [], 1), isNull);
    });
  });

  group('arcForDay', () {
    final arcs = [
      for (var w = 1; w <= 10; w++)
        WorldArc.fromJson({'week': w, 'id': 'w$w'}),
    ];

    test('maps each five-day window to its world (day-1)~/5', () {
      expect(arcForDay(arcs, 1)!.id, 'w1');
      expect(arcForDay(arcs, 5)!.id, 'w1');
      expect(arcForDay(arcs, 6)!.id, 'w2');
      expect(arcForDay(arcs, 21)!.id, 'w5');
      expect(arcForDay(arcs, 50)!.id, 'w10');
    });

    test('clamps out-of-range + null on empty', () {
      expect(arcForDay(arcs, 0)!.id, 'w1');
      expect(arcForDay(arcs, 99)!.id, 'w10');
      expect(arcForDay(const [], 5), isNull);
    });
  });
}
