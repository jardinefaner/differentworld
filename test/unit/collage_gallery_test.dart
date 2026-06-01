// The collage layout plan (docs/ACTIVITY_RUNTIME.md). Pure — which block
// kinds, in what order, consuming exactly N tiles. The pixel layout lives
// in the widget; this guarantees no tile is ever dropped or starved.

import 'package:differentworld/features/activity_runtime/collage_gallery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('planCollageBlocks', () {
    test('empty for zero / negative', () {
      expect(planCollageBlocks(0), isEmpty);
      expect(planCollageBlocks(-3), isEmpty);
    });

    test('consumes EXACTLY n tiles for every count 1..50', () {
      for (var n = 1; n <= 50; n++) {
        final plan = planCollageBlocks(n);
        final total = plan.fold<int>(0, (s, k) => s + k.tileCount);
        expect(total, n, reason: 'plan for $n must consume exactly $n tiles');
      }
    });

    test('tail fits exactly: 1 -> heroBig, 2 -> halves, 3 -> heroLeftStack', () {
      expect(planCollageBlocks(1), [CollageBlockKind.heroBig]);
      expect(planCollageBlocks(2), [CollageBlockKind.halves]);
      expect(planCollageBlocks(3), [CollageBlockKind.heroLeftStack]);
    });

    test('a real set varies the scale (not one repeated block)', () {
      expect(
        planCollageBlocks(12).toSet().length,
        greaterThan(1),
        reason: 'a collage should mix block sizes',
      );
    });
  });
}
