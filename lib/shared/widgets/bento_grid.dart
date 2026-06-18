import 'package:flutter/material.dart';

/// Per-breakpoint column span + row height for one [BentoTile].
///
/// The bento is ONE modular column grid that re-packs across devices — phone
/// (2 columns), tablet (4), desktop (6). A tile declares how many of those
/// columns it claims at each width, so the same content reflows without the
/// caller writing three layouts. `rows` scales the tile's *minimum* height
/// (content can grow past it — never a fixed box, so text-scale stays safe).
@immutable
class BentoSpan {
  const BentoSpan({
    this.phone = 2,
    this.tablet = 2,
    this.desktop = 2,
    this.rows = 1,
  });

  /// A full-bleed banner at every width (claims the whole row).
  const BentoSpan.wide({this.rows = 1})
      : phone = 2,
        tablet = 4,
        desktop = 6;

  /// The hero: full width on phone, two-thirds on tablet, two-thirds on
  /// desktop, and two rows tall.
  const BentoSpan.hero()
      : phone = 2,
        tablet = 4,
        desktop = 4,
        rows = 2;

  final int phone;
  final int tablet;
  final int desktop;
  final int rows;

  int forColumns(int columns) => switch (columns) {
        <= 2 => phone,
        <= 4 => tablet,
        _ => desktop,
      };
}

/// One module in a [BentoGrid]: a span + the widget that fills it. [id] keys
/// the tile so a list whose modules appear/vanish at runtime re-matches by
/// identity (the Wrap-children-need-keys rule — a missing key would let a
/// neighbouring tile inherit this one's Element and rebuild).
@immutable
class BentoTile {
  const BentoTile({required this.id, required this.span, required this.child});

  final String id;
  final BentoSpan span;
  final Widget child;
}

/// A responsive bento grid — modular tiles sized by importance, re-packing
/// across phone / tablet / desktop from a single tile list. Tiles flow in a
/// [Wrap]; each claims `span.forColumns(n)` of the breakpoint's columns and a
/// `rows`-scaled minimum height. Tiles taller than their neighbours leave the
/// run ragged rather than clipping — intentional, so large text never
/// overflows a fixed box.
class BentoGrid extends StatelessWidget {
  const BentoGrid({
    required this.tiles,
    this.gap = 12,
    this.baseRowHeight = 112,
    super.key,
  });

  final List<BentoTile> tiles;
  final double gap;

  /// Minimum height of a single-row tile; multi-row tiles scale up.
  final double baseRowHeight;

  static int columnsForWidth(double width) => switch (width) {
        < 600 => 2,
        < 1100 => 4,
        _ => 6,
      };

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = columnsForWidth(width);
        final unit = (width - (columns - 1) * gap) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final tile in tiles)
              _BentoCell(
                key: ValueKey('bento-${tile.id}'),
                width: _tileWidth(tile.span.forColumns(columns), columns, unit),
                minHeight:
                    tile.span.rows * baseRowHeight + (tile.span.rows - 1) * gap,
                child: tile.child,
              ),
          ],
        );
      },
    );
  }

  double _tileWidth(int span, int columns, double unit) {
    final clamped = span.clamp(1, columns);
    return clamped * unit + (clamped - 1) * gap;
  }
}

class _BentoCell extends StatelessWidget {
  const _BentoCell({
    required this.width,
    required this.minHeight,
    required this.child,
    super.key,
  });

  final double width;
  final double minHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: child,
      ),
    );
  }
}
