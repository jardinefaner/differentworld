// Text on an accent-tinted tile has to be readable.
//
// `AccentCardTile` composites its ground from the category accent
// (`alphaBlend(accent@0.14, surfaceContainerHighest)`), so every piece of text
// on it sits on a slightly different colour per card — which is exactly the
// case an eyeball cannot judge and a number can.
//
// The chips shipped blended into the accent for a "quiet register that matches
// the tile" and measured 1.79–3.65:1 across the deck, where AA for small text
// is 4.5. Not one accent passed. This is the check that would have said so.

import 'dart:math' as math;

import 'package:differentworld/app/design_tokens.dart';
import 'package:differentworld/app/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every accent the decks actually hand to a tile.
const _accents = <String, Color>{
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
  'lightBlue': ActivityPalette.lightBlue,
  'red': ActivityPalette.red,
  'brown': ActivityPalette.brown,
};

double _lin(double c) =>
    c <= 0.03928 ? c / 12.92 : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

double _lum(Color c) =>
    0.2126 * _lin(c.r) + 0.7152 * _lin(c.g) + 0.0722 * _lin(c.b);

double _ratio(Color a, Color b) {
  final la = _lum(a);
  final lb = _lum(b);
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// The tile's ground — kept in step with `AccentCardTile.build`.
Color _ground(Color accent, ColorScheme scheme) => Color.alphaBlend(
  accent.withValues(alpha: 0.14),
  scheme.surfaceContainerHighest,
);

void main() {
  /// Run [check] for every accent in both themes, collecting failures so the
  /// report names all of them rather than the first.
  void everyTile(
    String what,
    double bar,
    Color Function(ColorScheme scheme) ink,
  ) {
    final bad = <String>[];
    for (final theme in [buildLightTheme(), buildDarkTheme()]) {
      final scheme = theme.colorScheme;
      final mode = scheme.brightness == Brightness.light ? 'light' : 'dark';
      for (final entry in _accents.entries) {
        final r = _ratio(ink(scheme), _ground(entry.value, scheme));
        if (r < bar) {
          bad.add('$mode/${entry.key} ${r.toStringAsFixed(2)}');
        }
      }
    }
    expect(
      bad,
      isEmpty,
      reason:
          '$what needs $bar:1 on the tile ground and does not reach it '
          'on: ${bad.join(', ')}',
    );
  }

  test('the title clears AA', () {
    everyTile('the title', 4.5, (s) => s.onSurface);
  });

  test('a chip label clears AA', () {
    // 11sp — small text, so the 4.5 bar, not the 3.0 large-text one.
    everyTile('a chip label', 4.5, (s) => s.onSurface);
  });

  test('the TAGLINE does not clear AA — pinned, not excused', () {
    // 3.44–3.99:1 across the deck. It predates the chips and is not a colour
    // slip: `onSurfaceVariant` IS the theme's muted-text role, and it clears
    // AA on a plain surface. What pushes it under is the tile's own 14%
    // accent wash — so the fix is a DESIGN decision (lighten the wash, or
    // promote the tagline to `onSurface` and lose the hierarchy), not a
    // one-line swap, and it changes every card on the deck.
    //
    // Asserted at the measured floor rather than at 4.5, so the number is on
    // the record and cannot quietly get worse while somebody decides.
    var worst = 21.0;
    for (final theme in [buildLightTheme(), buildDarkTheme()]) {
      final scheme = theme.colorScheme;
      for (final accent in _accents.values) {
        worst = math.min(
          worst,
          _ratio(scheme.onSurfaceVariant, _ground(accent, scheme)),
        );
      }
    }
    expect(
      worst,
      greaterThanOrEqualTo(3.4),
      reason: 'the tagline got HARDER to read than it already was',
    );
    expect(
      worst,
      lessThan(4.5),
      reason:
          'the tagline now clears AA — delete this test and add the tagline '
          'to the everyTile checks above',
    );
  });

  test('a chip icon clears the non-text bar', () {
    everyTile('a chip icon', 3, (s) => s.onSurfaceVariant);
  });

  test(
    'the accent itself would NOT clear it — which is why it is not used',
    () {
      // The check that keeps the fix from being undone by someone restoring the
      // prettier version: if this ever passes, the palette changed and the
      // accent could carry text again.
      var worst = 21.0;
      for (final theme in [buildLightTheme(), buildDarkTheme()]) {
        final scheme = theme.colorScheme;
        for (final accent in _accents.values) {
          worst = math.min(worst, _ratio(accent, _ground(accent, scheme)));
        }
      }
      expect(
        worst,
        lessThan(4.5),
        reason:
            'the accent now clears AA against its own ground — the chips could '
            'carry it again, and the comment in _ChipRow needs revisiting',
      );
    },
  );
}
