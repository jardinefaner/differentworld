// Pins AppColors.onAccent — the foreground picker for content-accent fills
// (AccentCardTile, badges). The bug it prevents: hardcoded white on a LIGHT
// accent fails WCAG AA (white-on-amber ≈1.9:1). onAccent must return a DARK
// foreground on the light ActivityPalette fills, and — for ANY fill — must
// pick the higher-contrast of the two options (never the worse one).

import 'package:differentworld/app/design_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// WCAG contrast ratio using Flutter's own relative-luminance impl.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  // The light fills that FAILED with hardcoded white — these must get dark.
  // (tealDeep #1D7A6E is genuinely dark — white-on-it is correct and clears AA,
  // so it lives only in the full `palette` below, not here.)
  const lightFills = <String, Color>{
    'amber': ActivityPalette.amber,
    'yellow': ActivityPalette.yellow,
    'blue': ActivityPalette.blue,
    'teal': ActivityPalette.teal,
    'green': ActivityPalette.green,
    'cyan': ActivityPalette.cyan,
  };

  // The full deck palette — onAccent must pick the better foreground for each.
  const palette = <String, Color>{
    'blue': ActivityPalette.blue,
    'indigo': ActivityPalette.indigo,
    'teal': ActivityPalette.teal,
    'tealDeep': ActivityPalette.tealDeep,
    'amber': ActivityPalette.amber,
    'yellow': ActivityPalette.yellow,
    'pink': ActivityPalette.pink,
    'purple': ActivityPalette.purple,
    'deepPurple': ActivityPalette.deepPurple,
    'green': ActivityPalette.green,
    'cyan': ActivityPalette.cyan,
    'brown': ActivityPalette.brown,
  };

  group('onAccent returns a DARK foreground on the light fills', () {
    lightFills.forEach((name, fill) {
      test(name, () {
        expect(
          AppColors.onAccent(fill),
          Colors.black,
          reason: '$name is light → white would fail AA',
        );
      });
    });
  });

  test('onAccent never picks the lower-contrast foreground', () {
    palette.forEach((name, fill) {
      final picked = AppColors.onAccent(fill);
      final other = picked == Colors.white ? Colors.black : Colors.white;
      expect(
        _contrast(picked, fill),
        greaterThanOrEqualTo(_contrast(other, fill)),
        reason: '$name: onAccent chose the worse foreground',
      );
    });
  });

  test('the chosen foreground clears AA large-text (3:1) on every fill', () {
    // The tile titles are 18px w800 (WCAG "large text" → 3:1). Picking the
    // better of black/white guarantees this for any fill.
    palette.forEach((name, fill) {
      final ratio = _contrast(AppColors.onAccent(fill), fill);
      expect(
        ratio,
        greaterThanOrEqualTo(3.0),
        reason: '$name: ${ratio.toStringAsFixed(2)}:1 is below large-text AA',
      );
    });
  });
}
