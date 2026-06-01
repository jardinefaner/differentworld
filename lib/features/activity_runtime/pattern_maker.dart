import 'package:flutter/foundation.dart';

/// Pattern Maker (docs/ACTIVITY_RUNTIME.md). A kid draws or builds ONE tile
/// in real life, snaps a photo of it, and the app repeats it into a pattern
/// — the repeat is the reason to execute, and kaleidoscope mirroring turns
/// any scribble into symmetry. Learning through play: repetition, symmetry,
/// "what does my tile do when it meets itself?"
///
/// This file is the pure core (config + the mirror rule). The render lives
/// in `pattern_maker_screen.dart`; the math here is testable without a
/// camera or an image.
@immutable
class PatternConfig {
  const PatternConfig({this.tilesPerRow = 4, this.kaleidoscope = true});

  /// Tiles across (and down — the grid is square). 2 reads as a bold
  /// mandala; 6 reads as wallpaper.
  final int tilesPerRow;

  /// When true, alternate columns/rows are mirrored so adjacent tiles meet
  /// edge-to-edge — seamless symmetry from any tile. Off → a plain repeat.
  final bool kaleidoscope;

  PatternConfig copyWith({int? tilesPerRow, bool? kaleidoscope}) =>
      PatternConfig(
        tilesPerRow: tilesPerRow ?? this.tilesPerRow,
        kaleidoscope: kaleidoscope ?? this.kaleidoscope,
      );

  /// Mirror odd columns (horizontal symmetry) when kaleidoscope is on.
  bool flipX(int col) => kaleidoscope && col.isOdd;

  /// Mirror odd rows (vertical symmetry) when kaleidoscope is on.
  bool flipY(int row) => kaleidoscope && row.isOdd;

  int get tileCount => tilesPerRow * tilesPerRow;
}

/// The selectable grid densities.
const patternTileChoices = <int>[2, 3, 4, 6];

/// Open-ended prompts — the "rule" of the pattern. Imagination, not a
/// worksheet: each one gives a reason to make a careful, interesting tile.
const patternPrompts = <String>[
  'Draw a tiny tile — make every edge interesting.',
  'Make an ABAB pattern with two things that take turns.',
  'Build a row of 3 things, then repeat it.',
  'Use one shape and one color — let them dance.',
  'Draw something with a top, a side, and a corner.',
  'Make a tile that looks good upside-down too.',
];
