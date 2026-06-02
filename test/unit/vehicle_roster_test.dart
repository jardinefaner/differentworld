// The vehicle trip headcount helpers (docs/VISION.md vehicle safety ritual).
// The check-in gate that prevents leaving a child rides on headcountCleared,
// and the seed rides on parseRoster — so both are pinned here.

import 'dart:convert';

import 'package:differentworld/features/vehicles/vehicle_roster.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseRoster', () {
    test('null / empty / invalid / non-list → empty (never crashes)', () {
      expect(parseRoster(null), isEmpty);
      expect(parseRoster(''), isEmpty);
      expect(parseRoster('not json'), isEmpty);
      expect(parseRoster('{}'), isEmpty); // a Map, not a List
    });

    test('reads a JSON list of ids (coercing to strings)', () {
      expect(parseRoster(jsonEncode(['s1', 's2', 's3'])), ['s1', 's2', 's3']);
      expect(parseRoster('[1, 2]'), ['1', '2']);
    });
  });

  group('headcountCleared', () {
    test('an empty boarding list is cleared', () {
      expect(headcountCleared({}, {}), isTrue);
    });

    test('cleared only when every boarded child is off', () {
      expect(headcountCleared({'a', 'b'}, {'a', 'b'}), isTrue);
      expect(headcountCleared({'a', 'b'}, {'a'}), isFalse, reason: 'b still on');
      expect(headcountCleared({'a', 'b'}, {}), isFalse);
    });

    test('extra off-board ids do not break clearance (boarded ⊆ off)', () {
      expect(headcountCleared({'a'}, {'a', 'b', 'c'}), isTrue);
    });
  });
}
