// `ReorderableListView.onReorder` was deprecated for `onReorderItem` in
// Flutter 3.41, and the difference is not cosmetic: onReorder handed callers a
// PRE-removal newIndex that every caller had to adjust itself
// (`if (newIndex > oldIndex) newIndex -= 1`), while onReorderItem hands over
// the FINAL index. Migrating means DELETING that adjustment — and a migration
// that renames the callback but keeps the adjustment silently moves every
// downward drag one slot too far.
//
// Nothing pinned that behaviour when the four call sites were migrated on
// 2026-09-03, so this does. These reproduce the pure index maths the two
// shared helpers now perform.

import 'package:flutter_test/flutter_test.dart';

/// The post-migration rule, as `activities_providers.reorder` and
/// `day_template_providers.reorderBlocks` now implement it.
List<String> reorder(List<String> items, int oldIndex, int newIndex) {
  if (oldIndex < 0 || oldIndex >= items.length) return items;
  final out = List<String>.of(items);
  final target = newIndex.clamp(0, out.length - 1);
  final moved = out.removeAt(oldIndex);
  out.insert(target, moved);
  return out;
}

void main() {
  const abcd = ['a', 'b', 'c', 'd'];

  test('dragging the first item down one lands it second', () {
    // onReorderItem: dropping "a" after "b" reports newIndex 1, not 2.
    expect(reorder(abcd, 0, 1), ['b', 'a', 'c', 'd']);
  });

  test('dragging the first item to the end lands it last', () {
    expect(reorder(abcd, 0, 3), ['b', 'c', 'd', 'a']);
  });

  test('dragging the last item to the front lands it first', () {
    expect(reorder(abcd, 3, 0), ['d', 'a', 'b', 'c']);
  });

  test('dragging an item onto itself changes nothing', () {
    expect(reorder(abcd, 2, 2), abcd);
  });

  test('an out-of-range oldIndex is a no-op, not a crash', () {
    expect(reorder(abcd, 9, 0), abcd);
    expect(reorder(abcd, -1, 0), abcd);
  });

  test('a newIndex past the end clamps instead of throwing', () {
    expect(reorder(abcd, 0, 99), ['b', 'c', 'd', 'a']);
  });

  test('the OLD adjustment would now be wrong — the bug this guards', () {
    // What the pre-migration code did: subtract one when moving down. Under
    // onReorderItem that lands "a" at index 0 — i.e. the drag does nothing,
    // which is exactly the silent failure a rename-only migration causes.
    var target = 1;
    if (target > 0) target -= 1;
    final out = List<String>.of(abcd);
    final moved = out.removeAt(0);
    out.insert(target, moved);
    expect(
      out,
      abcd,
      reason: 'the stale adjustment silently swallows the drag',
    );
    expect(reorder(abcd, 0, 1), isNot(out));
  });
}
