import 'package:differentworld/features/activity_runtime/justified_gallery.dart'
    show JustifiedTile;
import 'package:flutter/widgets.dart';

/// A collage gallery — deliberately VARIED tile sizes (a big hero, a wide
/// banner, a hero + two stacked, thirds, halves) cycled into a rhythm so the
/// wall reads like a scrapbook collage, not a uniform grid. The opposite of
/// the orderly `JustifiedGallery`: there, every row shares one height; here,
/// sizes jump on purpose.
///
/// Reuses [JustifiedTile] so it's a drop-in swap at any existing call site —
/// the tile's `aspectRatio` is ignored (the collage imposes its own shapes)
/// and the `child` is expected to `BoxFit.cover` its box.
///
/// [planCollageBlocks] is the pure, tested part (which block kinds, in what
/// order, consuming exactly N tiles); the widget renders the plan at the
/// measured width.

/// A collage block — a full-width unit that consumes [tileCount] tiles and
/// lays them out at a distinctive scale.
enum CollageBlockKind {
  /// One photo, full width, tall (the showpiece).
  heroBig(1),

  /// One photo, full width, short + wide (a section banner).
  banner(1),

  /// A tall hero on the left + two stacked on the right.
  heroLeftStack(3),

  /// Two side-by-side squares.
  halves(2),

  /// Three across.
  thirds(3)
  ;

  const CollageBlockKind(this.tileCount);
  final int tileCount;
}

/// Plan the block sequence to lay [count] tiles out as a varied collage.
/// Cycles a fixed rhythm; the tail falls back to a block that fits the
/// remaining count EXACTLY (2 → halves, 1 → heroBig), so every tile lands
/// and no block is ever starved. The returned kinds' `tileCount`s sum to
/// [count].
List<CollageBlockKind> planCollageBlocks(int count) {
  if (count <= 0) return const [];
  // The rhythm: hero+stack (3) · halves (2) · big hero (1) · thirds (3) ·
  // banner (1) · halves (2). Tuned so a big tile never lands two blocks
  // running and the scales keep changing.
  const rhythm = <CollageBlockKind>[
    CollageBlockKind.heroLeftStack,
    CollageBlockKind.halves,
    CollageBlockKind.heroBig,
    CollageBlockKind.thirds,
    CollageBlockKind.banner,
    CollageBlockKind.halves,
  ];
  final out = <CollageBlockKind>[];
  var remaining = count;
  var r = 0;
  while (remaining > 0) {
    final candidate = rhythm[r % rhythm.length];
    r++;
    if (candidate.tileCount <= remaining) {
      out.add(candidate);
      remaining -= candidate.tileCount;
    } else {
      // Tail: the candidate is too big for what's left. Fit it exactly.
      out.add(
        remaining == 2 ? CollageBlockKind.halves : CollageBlockKind.heroBig,
      );
      remaining -= remaining == 2 ? 2 : 1;
    }
  }
  return out;
}

class CollageGallery extends StatelessWidget {
  const CollageGallery({
    required this.tiles,
    this.spacing = 4,
    this.borderRadius = 8,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final List<JustifiedTile> tiles;
  final double spacing;
  final double borderRadius;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - padding.horizontal;
        if (width <= 0) return const SizedBox.shrink();
        final plan = planCollageBlocks(tiles.length);
        final blocks = <Widget>[];
        var index = 0;
        for (final kind in plan) {
          final slice = <Widget>[
            for (var k = 0; k < kind.tileCount; k++) _wrap(tiles[index + k]),
          ];
          index += kind.tileCount;
          blocks.add(_block(kind, slice, width));
        }
        return SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var b = 0; b < blocks.length; b++) ...[
                if (b > 0) SizedBox(height: spacing),
                blocks[b],
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _wrap(JustifiedTile tile) => ClipRRect(
    borderRadius: BorderRadius.circular(borderRadius),
    child: tile.child,
  );

  Widget _block(CollageBlockKind kind, List<Widget> c, double w) {
    switch (kind) {
      case CollageBlockKind.heroBig:
        return SizedBox(height: w * 0.62, child: c[0]);
      case CollageBlockKind.banner:
        return SizedBox(height: w * 0.4, child: c[0]);
      case CollageBlockKind.halves:
        final side = (w - spacing) / 2;
        return SizedBox(
          height: side,
          child: Row(
            children: [
              Expanded(child: c[0]),
              SizedBox(width: spacing),
              Expanded(child: c[1]),
            ],
          ),
        );
      case CollageBlockKind.thirds:
        final side = (w - spacing * 2) / 3;
        return SizedBox(
          height: side,
          child: Row(
            children: [
              Expanded(child: c[0]),
              SizedBox(width: spacing),
              Expanded(child: c[1]),
              SizedBox(width: spacing),
              Expanded(child: c[2]),
            ],
          ),
        );
      case CollageBlockKind.heroLeftStack:
        final leftW = (w - spacing) * 0.6;
        return SizedBox(
          height: leftW, // square hero drives the band height
          child: Row(
            children: [
              SizedBox(width: leftW, child: c[0]),
              SizedBox(width: spacing),
              Expanded(
                child: Column(
                  children: [
                    Expanded(child: c[1]),
                    SizedBox(height: spacing),
                    Expanded(child: c[2]),
                  ],
                ),
              ),
            ],
          ),
        );
    }
  }
}
