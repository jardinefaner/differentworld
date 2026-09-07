import 'package:flutter/material.dart';

/// Flexible content beside a cluster of fixed-size controls, that **stacks
/// rather than overflowing** when the row is too narrow for both.
///
/// This is the shape behind a recurring defect class: a `Row` holding a name
/// (or title) plus several 48dp touch targets fits a 390dp phone and does not
/// fit a 320dp one, so the row overflows by 20-35dp and the controls are
/// clipped. `Expanded` on the content does not save it — the content shrinks
/// to zero and the FIXED children still don't fit. Shrinking the buttons isn't
/// an option either: 48dp is the accessibility floor.
///
/// So the honest answer is two lines. Below [stackBelow] the controls move
/// under the content, full width, keeping every target at full size; at or
/// above it, the layout is exactly the `Row` it replaces.
///
/// [stackBelow] is declared by the caller rather than measured because
/// measuring the controls' intrinsic width needs a layout pass this widget
/// would have to throw away. Pick the width at which one line genuinely stops
/// fitting; `scripts/check_overflow_matrix.sh` proves the number, so a wrong
/// guess fails loudly rather than shipping clipped.
class AdaptiveControlRow extends StatelessWidget {
  const AdaptiveControlRow({
    required this.content,
    required this.controls,
    this.stackBelow = 360,
    this.spacing = 8,
    this.stackedGap = 8,
    this.stackedAlignment = WrapAlignment.start,
    super.key,
  });

  /// The flexible part — a name, a title. `Expanded` on one line; full width
  /// when stacked.
  final Widget content;

  /// The fixed-size controls. Laid out in a [Wrap] when stacked, so an
  /// unusually long cluster flows onto a third line rather than overflowing
  /// again.
  final List<Widget> controls;

  /// Below this width the controls move to their own line.
  final double stackBelow;

  /// Gap between the controls.
  final double spacing;

  /// Gap between the content and the controls once stacked.
  final double stackedGap;

  /// Where the stacked controls sit. Left by default; pass
  /// [WrapAlignment.end] when the cluster reads as trailing actions.
  final WrapAlignment stackedAlignment;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide =
            constraints.maxWidth.isFinite && constraints.maxWidth >= stackBelow;
        if (wide) {
          return Row(
            children: [
              Expanded(child: content),
              for (final c in controls) ...[SizedBox(width: spacing), c],
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            content,
            SizedBox(height: stackedGap),
            Wrap(
              spacing: spacing,
              runSpacing: stackedGap,
              alignment: stackedAlignment,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: controls,
            ),
          ],
        );
      },
    );
  }
}
