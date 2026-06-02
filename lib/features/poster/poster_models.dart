/// Poster print options — how a single image is tiled across multiple
/// US-Letter pages so it can be printed and taped into one big image.
library;

/// How the source image is mapped onto the assembled poster grid.
enum PosterFit {
  /// Fill every page edge-to-edge, cropping the overflow. No white
  /// margins — the assembled poster is solid image. The default.
  fill,

  /// Fit the *whole* image; add thin white margins on the axis whose
  /// aspect doesn't match the grid. Nothing is cropped.
  whole,
}

/// One poster job's configuration.
class PosterOptions {
  const PosterOptions({
    this.grid = 2,
    this.fit = PosterFit.fill,
    this.labels = true,
  });

  /// N — the poster prints to an N×N grid of letter pages.
  /// 2 → 4 pages, 3 → 9, 4 → 16.
  final int grid;

  /// Cover vs contain.
  final PosterFit fit;

  /// Print a faint "R1·C2" registration label in each page's corner so
  /// the assembly order is obvious when you lay the pages out.
  final bool labels;

  /// Total printed pages: grid².
  int get pageCount => grid * grid;

  PosterOptions copyWith({int? grid, PosterFit? fit, bool? labels}) =>
      PosterOptions(
        grid: grid ?? this.grid,
        fit: fit ?? this.fit,
        labels: labels ?? this.labels,
      );
}
