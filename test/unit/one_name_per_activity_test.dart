// An activity has ONE name, wherever a staffer meets it.
//
// The same game is listed in two places — the activity library (the deck a
// staffer browses) and the cast launcher (what you put on a TV) — and the two
// grew apart: `/activity/as-if` was "Act It Out" in one and "As If" in the
// other, `/activity/starts-with` was "Beat the Letter" and "Letter Words",
// `/activity/this-or-that` was "Quick Picks" and "This or That".
//
// Nothing errors when they drift. The app simply appears to contain more
// activities than it does, and a staffer who liked one cannot find it again
// under the name they remember. "Act It Out" was the worst of them: it sat in
// the same list as Charades, whose own tagline is "Act it out".
//
// Both lists are hand-written in different files, so only a check keeps them
// honest.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Route segments whose game id differs from the slug (see game_registry).
const _slugOverrides = <String, String>{'starts-with': 'letter-words'};

void main() {
  final deckSrc = File(
    'lib/features/activity_runtime/brain_breaks_screen.dart',
  ).readAsStringSync();

  // title + route out of each DeckCard, in declaration order.
  final deck = RegExp(
    r"title: '([^']+)',\s*\n\s*tagline: '[^']*',\s*\n\s*icon:[^\n]*\n"
    r"\s*color:[^\n]*\n\s*lane:[^\n]*\n\s*route: '([^']+)'",
  ).allMatches(deckSrc).map((m) => (m.group(1)!, m.group(2)!)).toList();

  // id + title out of each GameDefinition.
  final titles = <String, String>{};
  for (final f in Directory('lib/features/games/games').listSync()) {
    if (!f.path.endsWith('_game.dart')) continue;
    final src = File(f.path).readAsStringSync();
    final id = RegExp("String get id => '([^']+)'").firstMatch(src);
    final t = RegExp("String get title => '([^']+)'").firstMatch(src);
    if (id != null && t != null) titles[id.group(1)!] = t.group(1)!;
  }

  test('the scan finds both lists', () {
    // Without this the suite passes vacuously the day either file is
    // reformatted and a regex stops matching.
    expect(
      deck.length,
      greaterThan(20),
      reason: 'deck scan matched almost nothing',
    );
    expect(
      titles.length,
      greaterThan(15),
      reason: 'registry scan matched almost nothing',
    );
  });

  test("a game-backed card uses the game's own title", () {
    final drift = <String>[];
    for (final (deckTitle, route) in deck) {
      final parts = route.split('/').where((s) => s.isNotEmpty).toList();
      if (parts.length != 2) continue;
      const kinds = {'activity', 'live', 'present'};
      if (!kinds.contains(parts.first)) continue;
      final id = _slugOverrides[parts[1]] ?? parts[1];
      final gameTitle = titles[id];
      // Not a registry game — nothing to match against.
      if (gameTitle == null) continue;
      if (gameTitle.toLowerCase() != deckTitle.toLowerCase()) {
        drift.add(
          '$route — library says "$deckTitle", cast launcher says "$gameTitle"',
        );
      }
    }
    expect(
      drift,
      isEmpty,
      reason:
          'the same activity is offered under two different names, so it '
          'reads as two activities and cannot be found again by the name a '
          'staffer remembers',
    );
  });

  test('no two cards in the library share a name', () {
    final seen = <String, int>{};
    for (final (t, _) in deck) {
      seen[t.toLowerCase()] = (seen[t.toLowerCase()] ?? 0) + 1;
    }
    expect(
      seen.entries.where((e) => e.value > 1).map((e) => e.key).toList(),
      isEmpty,
    );
  });
}
