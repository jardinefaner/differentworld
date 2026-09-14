// No route is declared twice.
//
// go_router matches the FIRST declaration and silently ignores every later
// one, so a duplicate does not error, does not warn, and does not fail
// `no_dead_links_test` — that test asks whether a path resolves, and a
// shadowed path resolves perfectly well, just to the wrong screen.
//
// Two shipped that way:
//   /program   — an early `redirect: '/settings/program'` alias shadowed the
//                Season Hub, so the drawer's "Program" row, the cockpit's
//                Worlds tool, the conductor and launch-readiness all landed
//                in settings. A whole screen unreachable.
//   /routines  — the kid-legible day shadowed the routine-script editor,
//                which nothing else linked to, so it had never been
//                reachable at all.
//
// Scanning the SOURCE rather than the built router is deliberate: the built
// router has already collapsed the duplicate, so by then there is nothing
// left to see. The question is "did a human write this path twice".

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File('lib/app/router.dart').readAsStringSync();

  /// Every `path: '…'` in declaration order, with its line number.
  final declared = <(String, int)>[];
  final lines = src.split('\n');
  final pathLine = RegExp(r"^\s*path: '([^']+)'");
  for (var i = 0; i < lines.length; i++) {
    final m = pathLine.firstMatch(lines[i]);
    if (m != null) declared.add((m.group(1)!, i + 1));
  }

  test('the scan finds the router at all', () {
    // Without this the suite passes vacuously the day the router is
    // reformatted and the regex stops matching.
    expect(declared.length, greaterThan(100));
    expect(declared.map((d) => d.$1), contains('/breaks'));
  });

  test('no path is declared twice', () {
    // Nested routes make a bare segment ('new', 'edit') legitimately repeat
    // under different parents; only absolute paths are globally unique.
    final absolute = declared.where((d) => d.$1.startsWith('/')).toList();
    final seen = <String, int>{};
    final shadowed = <String>[];
    for (final (path, line) in absolute) {
      if (seen[path] case final first?) {
        shadowed.add('$path — line $first wins, line $line is dead');
      } else {
        seen[path] = line;
      }
    }
    expect(
      shadowed,
      isEmpty,
      reason:
          'go_router takes the first match and drops the rest, silently: '
          '${shadowed.join(' | ')}',
    );
  });
}
