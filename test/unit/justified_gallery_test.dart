// The Google-Photos justified-rows layout (docs camera/gallery work).
// Full rows fill the width exactly (no right-edge gap); the last partial
// row stays at the target height; heights vary row to row.

import 'package:differentworld/features/activity_runtime/justified_gallery.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computeJustifiedRows', () {
    test('a full row fills the container width exactly', () {
      final rows = computeJustifiedRows(
        aspectRatios: [1, 1, 1, 1], // 4 squares
        containerWidth: 400,
        // targetRowHeight 150 + spacing 2 are the defaults.
      );
      // The first row is full (3 squares fit before overflowing 400).
      final row = rows.first;
      final total =
          row.widths.fold<double>(0, (s, w) => s + w) + 2 * (row.count - 1);
      expect(total, closeTo(400, 0.5), reason: 'no right-edge gap');
    });

    test('the last partial row keeps the target height (not stretched)', () {
      final rows = computeJustifiedRows(
        aspectRatios: [1.0], // one square in a wide container
        containerWidth: 1000, // default target height 150
      );
      expect(rows, hasLength(1));
      expect(rows.first.height, 150);
      expect(rows.first.widths.single, 150); // 1.0 * 150
    });

    test('varied aspect ratios produce more than one row, varied heights', () {
      final rows = computeJustifiedRows(
        aspectRatios: [1.5, 0.7, 1.0, 1.8, 0.6, 1.2, 1.0],
        containerWidth: 360,
        targetRowHeight: 140,
      );
      expect(rows.length, greaterThan(1));
      // Full rows fill the width; heights differ from the target as they
      // scale to fit.
      final heights = rows.map((r) => r.height).toSet();
      expect(heights.length, greaterThan(1), reason: 'sizes vary row to row');
    });

    test('respects maxRowHeight for a sparse wide row', () {
      final rows = computeJustifiedRows(
        aspectRatios: [3.0], // very wide, alone
        containerWidth: 1000,
        maxRowHeight: 200,
      );
      expect(rows.single.height, lessThanOrEqualTo(200));
    });

    test('empty input or zero width → no rows', () {
      expect(
        computeJustifiedRows(aspectRatios: [], containerWidth: 400),
        isEmpty,
      );
      expect(
        computeJustifiedRows(aspectRatios: [1], containerWidth: 0),
        isEmpty,
      );
    });
  });
}
