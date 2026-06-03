// The poster tiling geometry. Seamless assembly (pages abut with no
// overlap/gap) depends entirely on these pure functions agreeing between
// the isolate renderer and the on-screen preview — so they're pinned here.

import 'dart:math' as math;

import 'package:differentworld/features/poster/poster_engine.dart';
import 'package:differentworld/features/poster/poster_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const letterAspect = kLetterWidthIn / kLetterHeightIn; // 8.5 / 11

  group('posterPageCount', () {
    test('N×N pages', () {
      expect(posterPageCount(2), 4);
      expect(posterPageCount(3), 9);
      expect(posterPageCount(4), 16);
    });
  });

  group('posterCanvasAspect', () {
    test('a square grid keeps the single-page aspect at any N', () {
      // The whole point: the assembled poster is the same shape as one
      // page, so the preview can frame the image with one AspectRatio.
      expect(posterCanvasAspect(8.5, 11), closeTo(letterAspect, 1e-9));
    });
  });

  group('posterPageRect', () {
    test('row-major tiling, (0,0) top-left, pages exactly partition', () {
      // 2×2 over a 100×200 canvas → four 50×100 quadrants.
      expect(posterPageRect(2, 2, 0, 0, 100, 200), (0.0, 0.0, 50.0, 100.0));
      expect(posterPageRect(2, 2, 0, 1, 100, 200), (50.0, 0.0, 50.0, 100.0));
      expect(posterPageRect(2, 2, 1, 0, 100, 200), (0.0, 100.0, 50.0, 100.0));
      expect(posterPageRect(2, 2, 1, 1, 100, 200), (50.0, 100.0, 50.0, 100.0));
    });

    test('non-square grid (3 cols × 2 rows) partitions correctly', () {
      // 3 wide × 2 tall over 120×80 → 40×40 cells.
      expect(posterPageRect(3, 2, 0, 0, 120, 80), (0.0, 0.0, 40.0, 40.0));
      expect(posterPageRect(3, 2, 1, 2, 120, 80), (80.0, 40.0, 40.0, 40.0));
    });

    test('pages cover the canvas with no gap and no overlap', () {
      const cols = 3;
      const rows = 2;
      const cw = 99.0;
      const ch = 90.0;
      final (lastL, _, lastW, _) =
          posterPageRect(cols, rows, 0, cols - 1, cw, ch);
      expect(lastL + lastW, closeTo(cw, 1e-9));
      final (_, lastT, _, lastH) =
          posterPageRect(cols, rows, rows - 1, 0, cw, ch);
      expect(lastT + lastH, closeTo(ch, 1e-9));
    });
  });

  group('computePosterLayout', () {
    double mismatch(double a, double b) => a > b ? a / b : b / a;

    test('fitShape off → a plain square size×size of portrait pages', () {
      final l = computePosterLayout(
        const PosterOptions(size: 3, fitShape: false),
        2,
      );
      expect(l.cols, 3);
      expect(l.rows, 3);
      expect(l.landscape, isFalse);
    });

    test('the long edge == size; the minor edge stays >= 1', () {
      for (final asp in const [0.3, 0.8, 1.0, 1.5, 3.0]) {
        final l = computePosterLayout(const PosterOptions(size: 4), asp);
        expect(math.max(l.cols, l.rows), 4);
        expect(math.min(l.cols, l.rows), greaterThanOrEqualTo(1));
      }
    });

    test('a wide image yields a wider-than-tall poster', () {
      final l = computePosterLayout(const PosterOptions(size: 3), 2); // 2:1
      expect(l.canvasAspect, greaterThan(1.0));
      expect(l.assembledWidthIn, greaterThan(l.assembledHeightIn));
    });

    test('a tall image yields a taller-than-wide poster', () {
      final l = computePosterLayout(const PosterOptions(size: 3), 0.5); // 1:2
      expect(l.canvasAspect, lessThan(1.0));
      expect(l.assembledHeightIn, greaterThan(l.assembledWidthIn));
    });

    test('fit-to-shape matches the image at least as well as the square', () {
      const aspect = 1.6;
      final fitted = computePosterLayout(const PosterOptions(size: 3), aspect);
      final square = computePosterLayout(
        const PosterOptions(size: 3, fitShape: false),
        aspect,
      );
      expect(
        mismatch(fitted.canvasAspect, aspect),
        lessThanOrEqualTo(mismatch(square.canvasAspect, aspect)),
      );
    });

    test('A4 paper is carried through to the layout', () {
      final l = computePosterLayout(
        const PosterOptions(paper: PosterPaper.a4),
        1,
      );
      expect(l.paper, PosterPaper.a4);
    });
  });

  group('posterCoverCrop (fill)', () {
    test('a wider-than-canvas image crops the sides, keeps full height', () {
      final (l, t, w, h) = posterCoverCrop(2000, 1000, letterAspect);
      expect(t, 0); // no vertical crop
      expect(h, 1000); // full height kept
      expect(w, closeTo(1000 * letterAspect, 1e-6)); // width trimmed to aspect
      expect(l, closeTo((2000 - 1000 * letterAspect) / 2, 1e-6)); // centered
      expect(w / h, closeTo(letterAspect, 1e-9)); // crop matches canvas
    });

    test('a taller-than-canvas image crops top/bottom, keeps full width', () {
      final (l, t, w, h) = posterCoverCrop(1000, 3000, letterAspect);
      expect(l, 0); // no horizontal crop
      expect(w, 1000); // full width kept
      expect(h, closeTo(1000 / letterAspect, 1e-6));
      expect(t, closeTo((3000 - 1000 / letterAspect) / 2, 1e-6)); // centered
      expect(w / h, closeTo(letterAspect, 1e-9));
    });

    test('the crop region always matches the canvas aspect', () {
      for (final dims in const [[800, 800], [1600, 900], [600, 2000]]) {
        final (_, _, w, h) =
            posterCoverCrop(dims[0].toDouble(), dims[1].toDouble(), letterAspect);
        expect(w / h, closeTo(letterAspect, 1e-9));
      }
    });
  });

  group('posterContainPlacement (whole)', () {
    test('a square image fits the narrow axis, centers with margins', () {
      // Canvas is portrait (letter); a square image fits to width.
      final (l, t, w, h) = posterContainPlacement(1000, 1000, 850, 1100);
      expect(w, closeTo(850, 1e-6)); // limited by width
      expect(h, closeTo(850, 1e-6)); // square stays square (no distortion)
      expect(l, closeTo(0, 1e-6));
      expect(t, closeTo((1100 - 850) / 2, 1e-6)); // vertical margins
    });

    test('a wide image fits to width, leaves top/bottom margins', () {
      final (l, t, w, h) = posterContainPlacement(2000, 1000, 850, 1100);
      expect(w, closeTo(850, 1e-6));
      expect(h, closeTo(425, 1e-6)); // 850 * (1000/2000)
      expect(l, closeTo(0, 1e-6));
      expect(t, closeTo((1100 - 425) / 2, 1e-6));
    });

    test('the placed image preserves the source aspect (never distorts)', () {
      final (_, _, w, h) = posterContainPlacement(1600, 900, 850, 1100);
      expect(w / h, closeTo(1600 / 900, 1e-9));
    });
  });
}
