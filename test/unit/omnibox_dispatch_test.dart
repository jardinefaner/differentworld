// The omnibox is a DOORWAY, not a room.
//
// Selecting a result must pop `/search` BEFORE navigating, so the back stack
// reads [where I was] → [where I asked to go]. Leaving the search page in the
// middle makes back land on a surface the user only passed through — reported
// as "back goes to screens I didn't really go back to".
//
// This has been flipped once already: an earlier wave deliberately kept
// `/search` in the stack so back would restore the query and results. That
// trade buys re-running a search cheaply and costs the back button its meaning
// on every omnibox use. This test pins the current answer so the next flip is
// a deliberate edit to a stated intent, not a quiet drift.
//
// Source-level, because the alternative is booting the whole shell to assert a
// two-line ordering. Crude, but it fails loudly if `selectEntry` stops popping.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final src = File(
    'lib/features/omnibox/omnibox_search_screen.dart',
  ).readAsStringSync();

  /// The body of `selectEntry`, which is the one dispatch path that regressed.
  String selectEntryBody() {
    final start = src.indexOf('void selectEntry(');
    expect(start, greaterThan(-1), reason: 'selectEntry was renamed');
    final end = src.indexOf('\n    }', start);
    return src.substring(start, end);
  }

  test('selecting a result pops /search before it navigates', () {
    final body = selectEntryBody();
    final closeAt = body.indexOf('close()');
    final dispatchAt = body.indexOf('onSelect(');
    expect(
      closeAt,
      greaterThan(-1),
      reason:
          'selectEntry must call close() — without it the destination stacks '
          'ON TOP of /search and back returns to the search page.',
    );
    expect(
      closeAt,
      lessThan(dispatchAt),
      reason: 'close() must come BEFORE onSelect, not after.',
    );
  });

  test('it dispatches through the long-lived context, not its own', () {
    // Popping deactivates this page's context; dispatching through it means
    // the action silently never fires (CLAUDE.md interaction invariant).
    expect(
      selectEntryBody(),
      contains('onSelect(dispatchCtx'),
      reason:
          'After close() this page is torn down. onSelect must use the '
          'root-navigator context captured before the pop, or the tap does '
          'nothing at all — the silent kind of broken.',
    );
  });

  test('every dispatch path in the screen pops first', () {
    // slash commands, save-as-capture and result selection all leave the
    // search page. If one of them stops, back becomes inconsistent depending
    // on WHICH kind of thing you picked, which is worse than either rule.
    for (final call in ['onSelect(dispatchCtx', 'exec(dispatchCtx']) {
      final at = src.indexOf(call);
      expect(at, greaterThan(-1), reason: '$call missing');
      final before = src.substring(0, at);
      expect(
        before.lastIndexOf('close()'),
        greaterThan(before.lastIndexOf('void ')),
        reason: '$call is not preceded by a close() in its own handler',
      );
    }
  });

  test('selecting a result keeps the query; consuming it clears', () {
    // The two halves of "never get lost":
    //
    //   BACK        = navigation history. Pops to where you were.
    //   THE BOX     = tool state. Remembers your query independently.
    //
    // The old design used the back STACK to remember the query, which made
    // back mean something different after a search than anywhere else. These
    // are separate concerns and the fix is to keep them separate — the same
    // shape as a browser address bar or a command palette: back never returns
    // you to the search box, the search box just remembers.
    expect(
      selectEntryBody(),
      isNot(contains('omniboxQueryProvider.notifier).clear()')),
      reason:
          'A result is a LOOKUP — the text was not consumed, so it should '
          'survive for when the omnibox is reopened.',
    );

    // …but a slash command or a save-as-capture CONSUMED the text, so those
    // must clear. The asymmetry is the point, not an oversight.
    final consumed = src.indexOf('exec(dispatchCtx');
    expect(
      src.substring(0, consumed).lastIndexOf('clear()'),
      greaterThan(src.substring(0, consumed).lastIndexOf('void ')),
      reason: 'a slash command consumes the text and must clear it',
    );
  });

  test('the query provider outlives the page, or the box forgets', () {
    // If this were autoDispose, popping /search would drop the last watcher
    // and reset the query — the box would forget the moment you navigated,
    // which is the whole feature.
    final state = File(
      'lib/features/omnibox/omnibox_state.dart',
    ).readAsStringSync();
    final decl = state.substring(state.indexOf('omniboxQueryProvider'));
    expect(
      decl.split(';').first,
      isNot(contains('autoDispose')),
      reason:
          'omniboxQueryProvider must outlive the search page; autoDispose '
          'would clear the query on pop and the box would forget.',
    );
  });
}
