import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden tests compare pixel-exact by default. The floating-glass chrome's
/// `BackdropFilter` blur rasterises with tiny run-to-run differences — and the
/// UI north star (transparent chrome, see [[chrome-transparent-edge-to-edge]])
/// made that blur the VISIBLE chrome surface, so sub-pixel raster jitter now
/// trips the exact comparison and goldens flake (the fail count wandered
/// 4↔10 run-to-run for the same plates). A small tolerance absorbs that jitter
/// while still catching real visual regressions (a chrome/layout change moves
/// far more than 0.5% of the pixels).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final prev = goldenFileComparator;
  if (prev is LocalFileComparator) {
    // Re-anchor a tolerant comparator at the same base directory.
    goldenFileComparator = _TolerantComparator(
      Uri.parse('${prev.basedir}flutter_test_config.dart'),
      // 2%. The blur/gradient-heavy game-stage plates rasterise with ~1.5%
      // run-to-run jitter (BackdropFilter + LinearGradient stages); 0.5% tripped
      // them. A real visual regression moves far more than 2% on a full-screen
      // plate, so this catches regressions while ending the flake.
      tolerance: 0.02,
    );
  }
  await testMain();
}

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile, {required this.tolerance});

  /// Max fraction (0..1) of pixels allowed to differ before a golden fails.
  final double tolerance;

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    // The Flame game STAGE plates (`gallery/games/**`) compose animated
    // sprites + BackdropFilter blur + LinearGradients that rasterise several %
    // differently run-to-run — they can't be pixel-stable. Give them a wide
    // band; every other plate (the real screens) stays tight so genuine
    // regressions are still caught.
    final tol = golden.path.contains('/games/') ? 0.06 : tolerance;
    if (result.passed || result.diffPercent <= tol) return true;
    throw FlutterError(await generateFailureOutput(result, golden, basedir));
  }
}
