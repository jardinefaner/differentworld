// What do I type to set up a room?
//
// The omnibox scorer matches by SUBSTRING, which means short queries win and
// natural-sounding long ones silently miss: "room" hits, "add a room" matches
// nothing at all. That asymmetry is invisible from reading the catalogue, so
// the words a person would actually type are pinned here instead of assumed.
//
// A MISS in this file is not a test failure to route around — it is a keyword
// somebody needs, discovered before they did.

import 'package:differentworld/features/omnibox/omnibox_catalog.dart';
import 'package:differentworld/features/omnibox/omnibox_entries.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  OmniboxEntry entry(String label, List<String> keywords) => OmniboxEntry(
    id: 'test',
    label: label,
    category: OmniboxCategory.action,
    icon: Icons.add,
    keywords: keywords,
    onSelect: (_, _) {},
  );

  group('creating a room', () {
    // The REAL list the catalogue ships, not a copy of it.
    final e = entry('Add a classroom', kRoomCreationKeywords);

    for (final q in [
      'room',
      'rooms',
      'new room',
      'add a room',
      'make a room',
      'create room',
      'class',
      'new class',
      'classroom',
      'set up a room',
      'crew',
      'group',
    ]) {
      test('"$q" finds it', () {
        expect(
          e.score(q),
          greaterThan(0),
          reason:
              '"$q" is a thing a person types when they want a new room. '
              'Scoring 0 means the omnibox silently returns nothing.',
        );
      });
    }
  });

  group('the scorer\'s shape — why short queries win', () {
    final e = entry('Add a classroom', const ['create room']);

    test('a substring of the label scores high', () {
      expect(e.score('classroom'), 250);
    });

    test('a substring of a keyword scores low but non-zero', () {
      expect(e.score('create'), 80);
    });

    test('a longer phrase than any keyword scores ZERO', () {
      // The trap. "add a room to my program" contains a real keyword, but
      // matching runs the other way — the KEYWORD must contain the QUERY.
      expect(e.score('add a room to my program'), 0);
    });
  });
}
