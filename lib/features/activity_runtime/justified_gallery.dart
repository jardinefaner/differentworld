import 'package:flutter/widgets.dart';

/// A Google-Photos-style justified gallery: photos kept at their true
/// shape, packed left-to-right into rows that each fill the full width
/// with (near-)zero gaps, so sizes vary row to row and it reads as a dense,
/// interesting mosaic — never a uniform grid.
///
/// The layout math ([computeJustifiedRows]) is pure + tested; the widget
/// just renders it.

/// One laid-out row: its [height] and each item's [widths] (input order).
class JustifiedRow {
  const JustifiedRow({required this.height, required this.widths});
  final double height;
  final List<double> widths;
  int get count => widths.length;
}

/// Greedily fill rows to [containerWidth] at roughly [targetRowHeight],
/// then scale each FULL row's height so it fits the width exactly (that's
/// what removes the right-edge gap and makes sizes vary). The last partial
/// row renders at [targetRowHeight], left-aligned (Google Photos does the
/// same). Heights are clamped to [maxRowHeight] so a row of a few wide
/// photos can't balloon.
List<JustifiedRow> computeJustifiedRows({
  required List<double> aspectRatios, // width / height per item
  required double containerWidth,
  double targetRowHeight = 150,
  double spacing = 2,
  double maxRowHeight = 320,
}) {
  if (containerWidth <= 0 || aspectRatios.isEmpty) return const [];
  final rows = <JustifiedRow>[];
  var i = 0;
  final n = aspectRatios.length;
  while (i < n) {
    var arSum = 0.0;
    var j = i;
    var filled = false;
    while (j < n) {
      final ar = aspectRatios[j] <= 0 ? 1.0 : aspectRatios[j];
      arSum += ar;
      final count = j - i + 1;
      final widthAtTarget = targetRowHeight * arSum + spacing * (count - 1);
      j++;
      if (widthAtTarget >= containerWidth) {
        filled = true;
        break;
      }
    }
    final rowArs = [
      for (var k = i; k < j; k++)
        if (aspectRatios[k] <= 0) 1.0 else aspectRatios[k],
    ];
    final count = rowArs.length;
    final arRowSum = rowArs.fold<double>(0, (s, ar) => s + ar);
    double height;
    if (filled) {
      final avail = containerWidth - spacing * (count - 1);
      height = avail / arRowSum;
    } else {
      height = targetRowHeight; // last partial row, not stretched
    }
    if (height > maxRowHeight) height = maxRowHeight;
    rows.add(
      JustifiedRow(
        height: height,
        widths: [for (final ar in rowArs) height * ar],
      ),
    );
    i = j;
  }
  return rows;
}

class JustifiedTile {
  const JustifiedTile({required this.aspectRatio, required this.child});
  final double aspectRatio;
  final Widget child;
}

class JustifiedGallery extends StatelessWidget {
  const JustifiedGallery({
    required this.tiles,
    this.targetRowHeight = 150,
    this.spacing = 2,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final List<JustifiedTile> tiles;
  final double targetRowHeight;
  final double spacing;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth - padding.horizontal;
        final rows = computeJustifiedRows(
          aspectRatios: [for (final t in tiles) t.aspectRatio],
          containerWidth: width,
          targetRowHeight: targetRowHeight,
          spacing: spacing,
        );
        var index = 0;
        final rowWidgets = <Widget>[];
        for (final row in rows) {
          final children = <Widget>[];
          for (var k = 0; k < row.count; k++) {
            if (k > 0) children.add(SizedBox(width: spacing));
            children.add(
              SizedBox(
                width: row.widths[k],
                height: row.height,
                child: tiles[index].child,
              ),
            );
            index++;
          }
          rowWidgets.add(
            Padding(
              padding: EdgeInsets.only(bottom: spacing),
              child: Row(children: children),
            ),
          );
        }
        return SingleChildScrollView(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: rowWidgets,
          ),
        );
      },
    );
  }
}
